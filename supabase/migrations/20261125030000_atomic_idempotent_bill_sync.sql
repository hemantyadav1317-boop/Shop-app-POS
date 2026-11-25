-- Vyapar/Billiez-grade atomic & idempotent serial billing migration:
-- 1. Adds client_ref idempotency column + partial unique index on public.sales
-- 2. Resets any pre-burned shop_bill_counters back to actual MAX(bill_no) in sales
-- 3. Restricts get_next_bill_no() to internal atomic transactions only (no standalone client burn)
-- 4. Makes create_sale() idempotent on __POS_META__ 'cref' under per-shop advisory lock

ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS client_ref text;

CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_shop_client_ref
  ON public.sales (shop_id, client_ref)
  WHERE client_ref IS NOT NULL;

-- One-time repair: align every shop's counter strictly to its highest real bill_no in public.sales
-- so previously leaked counter gaps do not carry forward into future bills.
INSERT INTO public.shop_bill_counters (shop_id, last_bill_no, updated_at)
SELECT s.id, COALESCE(MAX(b.bill_no), 0), now()
FROM public.shops s
LEFT JOIN public.sales b ON b.shop_id = s.id AND b.bill_no < 1000000000
GROUP BY s.id
ON CONFLICT (shop_id) DO UPDATE
SET last_bill_no = EXCLUDED.last_bill_no,
    updated_at = now();

-- Only SECURITY DEFINER transactional RPCs (like create_sale) may call get_next_bill_no().
-- Direct client RPC calls cannot burn counter numbers outside a committed sale transaction.
REVOKE ALL ON FUNCTION public.get_next_bill_no(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_sale(
  _shop_id uuid,
  _items jsonb,
  _discount numeric,
  _payment_mode public.payment_mode,
  _paid numeric,
  _customer_id uuid,
  _customer_name text,
  _customer_phone text,
  _note text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _sale_id uuid;
  _existing_sale_id uuid;
  _bill_no integer;
  _sub numeric(12,2) := 0;
  _total numeric(12,2);
  _due numeric(12,2);
  _cust_bal numeric(12,2);
  _meta_pos integer;
  _meta_json jsonb;
  _round_off numeric(12,2) := 0;
  _client_created_at timestamptz;
  _effective_created_at timestamptz := now();
  _client_ref text;
  it jsonb;
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN
    RAISE EXCEPTION 'not authorized for this shop';
  END IF;

  -- Serialize all bill numbering & idempotency checks per shop
  PERFORM pg_advisory_xact_lock(hashtextextended(_shop_id::text, 2));

  -- Safely parse optional __POS_META__ JSON suffix from _note
  IF _note IS NOT NULL THEN
    _meta_pos := position('__POS_META__' IN _note);
    IF _meta_pos > 0 THEN
      BEGIN
        _meta_json := substring(_note FROM (_meta_pos + 12))::jsonb;
        IF (_meta_json ? 'ro') THEN
          _round_off := LEAST(1.00, GREATEST(-1.00, COALESCE((_meta_json->>'ro')::numeric, 0)));
        END IF;
        IF (_meta_json ? 'ca') AND NULLIF(_meta_json->>'ca', '') IS NOT NULL THEN
          _client_created_at := (_meta_json->>'ca')::timestamptz;
          IF _client_created_at <= (now() + interval '2 minutes')
             AND _client_created_at >= (now() - interval '365 days') THEN
            _effective_created_at := _client_created_at;
          END IF;
        END IF;
        IF (_meta_json ? 'cref') AND NULLIF(TRIM(_meta_json->>'cref'), '') IS NOT NULL THEN
          _client_ref := NULLIF(TRIM(_meta_json->>'cref'), '');
        END IF;
      EXCEPTION WHEN OTHERS THEN
        _round_off := 0;
        _effective_created_at := now();
        _client_ref := NULL;
      END;
    END IF;
  END IF;

  -- Idempotency check: if a retry sends the same client_ref, return existing sale without burning a bill_no
  IF _client_ref IS NOT NULL THEN
    SELECT id INTO _existing_sale_id
    FROM public.sales
    WHERE shop_id = _shop_id
      AND (
        client_ref = _client_ref
        OR (_client_ref ~ '^[A-Za-z0-9_-]+$' AND note LIKE '%"cref":"' || _client_ref || '"%')
      )
    LIMIT 1;

    IF _existing_sale_id IS NOT NULL THEN
      RETURN _existing_sale_id;
    END IF;
  END IF;

  -- Allocate atomic bill number strictly inside this transaction
  _bill_no := public.get_next_bill_no(_shop_id);

  FOR it IN SELECT * FROM jsonb_array_elements(_items) LOOP
    _sub := _sub + ((it->>'price')::numeric * (it->>'qty')::numeric);
  END LOOP;

  _total := GREATEST(0, ROUND(_sub - COALESCE(_discount,0) + _round_off, 2));
  _due := GREATEST(0, _total - COALESCE(_paid,0));

  INSERT INTO public.sales (shop_id, bill_no, client_ref, customer_id, customer_name, customer_phone,
    sub_total, discount, total, paid, due, payment_mode, note, created_by, created_at, updated_at)
  VALUES (_shop_id, _bill_no, _client_ref, _customer_id, _customer_name, _customer_phone,
    _sub, COALESCE(_discount,0), _total, COALESCE(_paid,0), _due, _payment_mode, _note, auth.uid(), _effective_created_at, now())
  RETURNING id INTO _sale_id;

  FOR it IN SELECT * FROM jsonb_array_elements(_items) LOOP
    INSERT INTO public.sale_items (shop_id, sale_id, product_id, name, unit, price, qty, line_total)
    VALUES (_shop_id, _sale_id, NULLIF(it->>'product_id','')::uuid, it->>'name',
      COALESCE((it->>'unit')::public.unit_type,'kg'), (it->>'price')::numeric, (it->>'qty')::numeric,
      (it->>'price')::numeric * (it->>'qty')::numeric);

    IF NULLIF(it->>'product_id','') IS NOT NULL THEN
      UPDATE public.products SET stock = stock - (it->>'qty')::numeric
      WHERE id = (it->>'product_id')::uuid AND shop_id = _shop_id;
      INSERT INTO public.stock_movements (shop_id, product_id, change, reason, ref_id)
      VALUES (_shop_id, (it->>'product_id')::uuid, -((it->>'qty')::numeric), 'sale', _sale_id);
    END IF;
  END LOOP;

  IF COALESCE(_paid,0) > 0 THEN
    INSERT INTO public.payments (shop_id, sale_id, customer_id, amount, mode, created_by)
    VALUES (_shop_id, _sale_id, _customer_id, _paid, _payment_mode, auth.uid());
  END IF;

  IF _due > 0 AND _customer_id IS NOT NULL THEN
    SELECT balance INTO _cust_bal FROM public.customers WHERE id = _customer_id AND shop_id = _shop_id FOR UPDATE;
    _cust_bal := COALESCE(_cust_bal, 0) + _due;
    UPDATE public.customers SET balance = _cust_bal, updated_at = now() WHERE id = _customer_id AND shop_id = _shop_id;

    INSERT INTO public.customer_ledger (shop_id, customer_id, entry_type, amount, balance_after, sale_id, note, created_by)
    VALUES (_shop_id, _customer_id, 'credit_sale', _due, _cust_bal, _sale_id, 'Credit on Bill #' || _bill_no, auth.uid());
  END IF;

  RETURN _sale_id;
END;
$$;
