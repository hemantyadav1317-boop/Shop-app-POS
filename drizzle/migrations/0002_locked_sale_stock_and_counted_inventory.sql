CREATE OR REPLACE FUNCTION public.validate_sale_stock(_shop_id uuid, _items jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE p public.products; requested numeric; allow_negative boolean;
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN RAISE EXCEPTION 'not authorized for this shop'; END IF;
  SELECT allow_negative_stock INTO allow_negative FROM public.shops WHERE id = _shop_id FOR SHARE;
  FOR p IN SELECT * FROM public.products WHERE shop_id = _shop_id AND id IN (SELECT NULLIF(value->>'product_id','')::uuid FROM jsonb_array_elements(_items)) ORDER BY id FOR UPDATE LOOP
    SELECT sum((value->>'qty')::numeric) INTO requested FROM jsonb_array_elements(_items) WHERE NULLIF(value->>'product_id','')::uuid = p.id;
    IF NOT p.is_active THEN RAISE EXCEPTION 'Product unavailable: %', p.name; END IF;
    IF NOT COALESCE(allow_negative,false) AND p.stock < requested THEN RAISE EXCEPTION 'Insufficient stock for %: available % %, requested %', p.name, p.stock, p.unit, requested; END IF;
  END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION public.validate_sale_stock(uuid,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_sale_stock(uuid,jsonb) TO authenticated, service_role;
DO $$
DECLARE definition text; marker text := 'SELECT COALESCE(MAX(bill_no),0)+1';
BEGIN
  SELECT pg_get_functiondef('public.create_sale(uuid,jsonb,numeric,public.payment_mode,numeric,uuid,text,text,text)'::regprocedure) INTO definition;
  IF position('PERFORM public.validate_sale_stock(_shop_id, _items);' IN definition) = 0 THEN
    IF position(marker IN definition) = 0 THEN RAISE EXCEPTION 'Sale function differs from expected version'; END IF;
    EXECUTE replace(definition, marker, E'PERFORM public.validate_sale_stock(_shop_id, _items);\n  SELECT COALESCE(MAX(bill_no),0)+1');
  END IF;
END;
$$;
CREATE OR REPLACE FUNCTION public.reconcile_inventory(_product_id uuid, _expected_stock numeric, _counted_stock numeric, _note text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE p public.products; previous_operation text;
BEGIN
  SELECT * INTO p FROM public.products WHERE id = _product_id FOR UPDATE;
  IF p.id IS NULL OR NOT public.is_shop_owner(p.shop_id) THEN RAISE EXCEPTION 'Only the shop owner can reconcile inventory'; END IF;
  IF _counted_stock IS NULL OR _counted_stock < 0 OR _counted_stock::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Enter a non-negative physical count'; END IF;
  IF p.stock IS DISTINCT FROM _expected_stock THEN RAISE EXCEPTION 'Stock changed. Refresh and count again before saving'; END IF;
  IF NULLIF(btrim(_note),'') IS NULL THEN RAISE EXCEPTION 'A count adjustment reason is required'; END IF;
  IF p.stock = _counted_stock THEN RETURN; END IF;
  previous_operation := COALESCE(current_setting('app.stock_operation',true),'');
  PERFORM set_config('app.stock_operation','purchase',true);
  UPDATE public.products SET stock = _counted_stock WHERE id = p.id;
  INSERT INTO public.stock_movements(shop_id,product_id,change,reason,note) VALUES(p.shop_id,p.id,_counted_stock-p.stock,'adjustment',btrim(_note) || ' [physical count; by ' || auth.uid()::text || ']');
  PERFORM set_config('app.stock_operation',previous_operation,true);
END;
$$;
REVOKE ALL ON FUNCTION public.reconcile_inventory(uuid,numeric,numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_inventory(uuid,numeric,numeric,text) TO authenticated, service_role;
ALTER TABLE public.saved_orders ADD COLUMN IF NOT EXISTS discount numeric NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS customer_id uuid;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.saved_orders TO authenticated;
GRANT ALL ON public.saved_orders TO service_role;