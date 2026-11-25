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
