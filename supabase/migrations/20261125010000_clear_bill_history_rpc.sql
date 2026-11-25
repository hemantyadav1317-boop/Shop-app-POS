-- Owner-only atomic RPC to clear bill history for a shop and optionally reset sequential numbering back to #1
CREATE OR REPLACE FUNCTION public.clear_shop_bill_history(
  _shop_id uuid,
  _reset_counter boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _deleted_count integer := 0;
BEGIN
  IF NOT public.has_shop_role(_shop_id, ARRAY['owner']::public.shop_role[]) THEN
    RAISE EXCEPTION 'only shop owner can clear bill history';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(_shop_id::text, 2));

  DELETE FROM public.sales WHERE shop_id = _shop_id;
  GET DIAGNOSTICS _deleted_count = ROW_COUNT;

  IF _reset_counter THEN
    INSERT INTO public.shop_bill_counters (shop_id, last_bill_no, updated_at)
    VALUES (_shop_id, 0, now())
    ON CONFLICT (shop_id) DO UPDATE
    SET last_bill_no = 0,
        updated_at = now();
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'deleted_count', _deleted_count,
    'counter_reset', _reset_counter
  );
END;
$$;

REVOKE ALL ON FUNCTION public.clear_shop_bill_history(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.clear_shop_bill_history(uuid, boolean) TO authenticated;
