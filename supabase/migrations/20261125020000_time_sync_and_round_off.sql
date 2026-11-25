-- Upgrade create_sale RPC to honor client-calibrated UTC billing timestamp ('ca')
-- and Round-Off adjustment ('ro') encoded inside __POS_META__ in _note.
-- Keeps the exact 9-parameter signature for 100% backwards compatibility.
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
  it jsonb;
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN
    RAISE EXCEPTION 'not authorized for this shop';
  END IF;

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
          -- Reject absurd future timestamps (> 2 min) or stale > 365 days
          IF _client_created_at <= (now() + interval '2 minutes')
             AND _client_created_at >= (now() - interval '365 days') THEN
            _effective_created_at := _client_created_at;
          END IF;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        _round_off := 0;
        _effective_created_at := now();
      END;
    END IF;
  END IF;

  -- Allocate atomic bill number safely
  _bill_no := public.get_next_bill_no(_shop_id);

  FOR it IN SELECT * FROM jsonb_array_elements(_items) LOOP
    _sub := _sub + ((it->>'price')::numeric * (it->>'qty')::numeric);
  END LOOP;

  _total := GREATEST(0, ROUND(_sub - COALESCE(_discount,0) + _round_off, 2));
  _due := GREATEST(0, _total - COALESCE(_paid,0));

  INSERT INTO public.sales (shop_id, bill_no, customer_id, customer_name, customer_phone,
    sub_total, discount, total, paid, due, payment_mode, note, created_by, created_at, updated_at)
  VALUES (_shop_id, _bill_no, _customer_id, _customer_name, _customer_phone,
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

    -- Add credit sale to immutable ledger
    INSERT INTO public.customer_ledger (shop_id, customer_id, entry_type, amount, balance_after, sale_id, note, created_by)
    VALUES (_shop_id, _customer_id, 'credit_sale', _due, _cust_bal, _sale_id, 'Credit on Bill #' || _bill_no, auth.uid());
  END IF;

  RETURN _sale_id;
END;
$$;
