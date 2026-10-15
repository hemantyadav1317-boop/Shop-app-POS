ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS upi_id text;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS upi_payee_name text;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS client_ref text;
CREATE UNIQUE INDEX IF NOT EXISTS sales_shop_client_ref_uidx ON public.sales(shop_id, client_ref) WHERE client_ref IS NOT NULL;

CREATE OR REPLACE FUNCTION public.create_sale_once(
  _client_ref text, _shop_id uuid, _items jsonb, _discount numeric, _payment_mode public.payment_mode,
  _paid numeric, _customer_id uuid, _customer_name text, _customer_phone text, _note text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _id uuid;
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN RAISE EXCEPTION 'not authorized for this shop'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(_shop_id::text || coalesce(_client_ref,'')));
  SELECT id INTO _id FROM public.sales WHERE shop_id = _shop_id AND client_ref = _client_ref;
  IF _id IS NOT NULL THEN RETURN _id; END IF;
  _id := public.create_sale(_shop_id, _items, _discount, _payment_mode, _paid, _customer_id, _customer_name, _customer_phone, _note);
  UPDATE public.sales SET client_ref = _client_ref WHERE id = _id;
  RETURN _id;
END; $$;
REVOKE EXECUTE ON FUNCTION public.create_sale_once(text,uuid,jsonb,numeric,public.payment_mode,numeric,uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_sale_once(text,uuid,jsonb,numeric,public.payment_mode,numeric,uuid,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.confirm_sale_payment(_sale_id uuid, _amount numeric, _mode public.payment_mode)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s public.sales; _amt numeric(12,2);
BEGIN
  SELECT * INTO s FROM public.sales WHERE id = _sale_id FOR UPDATE;
  IF s.id IS NULL OR NOT public.is_shop_member(s.shop_id) THEN RAISE EXCEPTION 'not authorized'; END IF;
  _amt := LEAST(GREATEST(COALESCE(_amount,0),0), s.due);
  IF _amt <= 0 THEN RETURN; END IF;
  UPDATE public.sales SET paid = paid + _amt, due = due - _amt WHERE id = _sale_id;
  INSERT INTO public.payments (shop_id, sale_id, customer_id, amount, mode, note, created_by)
  VALUES (s.shop_id, _sale_id, s.customer_id, _amt, _mode, 'Bill payment confirmed', auth.uid());
  IF s.customer_id IS NOT NULL THEN
    UPDATE public.customers SET balance = GREATEST(0, balance - _amt) WHERE id = s.customer_id AND shop_id = s.shop_id;
  END IF;
END; $$;
REVOKE EXECUTE ON FUNCTION public.confirm_sale_payment(uuid,numeric,public.payment_mode) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_sale_payment(uuid,numeric,public.payment_mode) TO authenticated;