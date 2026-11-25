-- Upgrade get_next_bill_no so server counter never falls behind direct table upserts
CREATE OR REPLACE FUNCTION public.get_next_bill_no(_shop_id uuid)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _legit_max integer;
  _next integer;
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN
    RAISE EXCEPTION 'not authorized for this shop';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(_shop_id::text, 2));

  SELECT COALESCE(MAX(bill_no), 0) INTO _legit_max
  FROM public.sales
  WHERE shop_id = _shop_id AND bill_no < 1000000000;

  INSERT INTO public.shop_bill_counters (shop_id, last_bill_no, updated_at)
  VALUES (_shop_id, _legit_max + 1, now())
  ON CONFLICT (shop_id) DO UPDATE
  SET last_bill_no = GREATEST(
        CASE WHEN shop_bill_counters.last_bill_no >= 1000000000 THEN 0 ELSE shop_bill_counters.last_bill_no END,
        _legit_max
      ) + 1,
      updated_at = now()
  RETURNING last_bill_no INTO _next;

  RETURN _next;
END;
$$;

REVOKE ALL ON FUNCTION public.get_next_bill_no(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_next_bill_no(uuid) TO authenticated;

-- Remove hardcoded LIMIT 200 on staff_get_sales so paired staff devices also see full history down to Bill #1
CREATE OR REPLACE FUNCTION public.staff_get_sales(
  _shop_id text,
  _pin text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _shop record;
  _sales jsonb;
BEGIN
  SELECT * INTO _shop FROM public.shops
  WHERE id::text = _shop_id
    AND (
      share_code = _pin
      OR bill_prefix = _pin
      OR bill_prefix = ('PIN:' || _pin)
      OR (share_code IS NULL AND (abs(hashtext(id::text)) % 900000 + 100000)::text = _pin)
    )
  LIMIT 1;

  IF _shop.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'अनधिकृत स्टाफ अनुरोध');
  END IF;

  SELECT coalesce(jsonb_agg(
    to_jsonb(s.*) || jsonb_build_object(
      'sale_items', coalesce((
        SELECT jsonb_agg(to_jsonb(si.*))
        FROM public.sale_items si
        WHERE si.sale_id = s.id
      ), '[]'::jsonb)
    )
    ORDER BY s.created_at DESC
  ), '[]'::jsonb)
  INTO _sales
  FROM (
    SELECT * FROM public.sales
    WHERE shop_id = _shop.id
    ORDER BY created_at DESC
  ) s;

  RETURN jsonb_build_object('success', true, 'sales', _sales);
END;
$$;
GRANT EXECUTE ON FUNCTION public.staff_get_sales(text, text) TO anon, authenticated, service_role;
