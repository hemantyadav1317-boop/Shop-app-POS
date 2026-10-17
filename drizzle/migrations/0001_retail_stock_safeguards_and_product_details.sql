ALTER TABLE public.shops ADD COLUMN allow_negative_stock boolean NOT NULL DEFAULT false;
ALTER TABLE public.products ADD COLUMN sku text, ADD COLUMN barcode text, ADD COLUMN name_en text, ADD COLUMN name_hi text, ADD COLUMN image_url text;
CREATE OR REPLACE FUNCTION public.guard_stock_change() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NEW.stock < 0 AND (TG_OP='INSERT' OR NEW.stock < OLD.stock) AND NOT (SELECT allow_negative_stock FROM public.shops WHERE id=NEW.shop_id) THEN
 RAISE EXCEPTION 'Insufficient stock for %: available % %', NEW.name, CASE WHEN TG_OP='INSERT' THEN 0 ELSE OLD.stock END, NEW.unit;
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER prevent_unapproved_negative_stock BEFORE INSERT OR UPDATE OF stock ON public.products FOR EACH ROW EXECUTE FUNCTION public.guard_stock_change();
CREATE OR REPLACE FUNCTION public.set_negative_stock_policy(_shop_id uuid, _enabled boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NOT public.is_shop_owner(_shop_id) THEN RAISE EXCEPTION 'Only the shop owner can change this setting'; END IF;
 UPDATE public.shops SET allow_negative_stock=_enabled WHERE id=_shop_id;
END; $$;
CREATE OR REPLACE FUNCTION public.protect_stock_policy() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NEW.allow_negative_stock IS DISTINCT FROM OLD.allow_negative_stock AND NOT public.is_shop_owner(OLD.id) THEN RAISE EXCEPTION 'Only the shop owner can change this setting'; END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER protect_negative_stock_policy BEFORE UPDATE OF allow_negative_stock ON public.shops FOR EACH ROW EXECUTE FUNCTION public.protect_stock_policy();
CREATE OR REPLACE FUNCTION public.audit_manual_stock_change() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF COALESCE(current_setting('app.stock_operation',true),'') NOT IN ('sale','purchase') THEN
 IF TG_OP='INSERT' THEN
 INSERT INTO public.stock_movements(shop_id,product_id,change,reason,note) VALUES(NEW.shop_id,NEW.id,NEW.stock,'opening','Opening stock recorded');
 ELSIF NEW.stock IS DISTINCT FROM OLD.stock THEN
 INSERT INTO public.stock_movements(shop_id,product_id,change,reason,note) VALUES(NEW.shop_id,NEW.id,NEW.stock-OLD.stock,'adjustment','Physical count / inventory edit');
 END IF;
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER audit_inventory_edits AFTER INSERT OR UPDATE OF stock ON public.products FOR EACH ROW EXECUTE FUNCTION public.audit_manual_stock_change();
DO $$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef(oid) INTO d FROM pg_proc WHERE oid='public.create_sale(uuid,jsonb,numeric,public.payment_mode,numeric,uuid,text,text,text)'::regprocedure;
 d:=replace(d,'SELECT COALESCE(MAX(bill_no),0)+1', E'PERFORM set_config(''app.stock_operation'',''sale'',true);\n  PERFORM pg_advisory_xact_lock(hashtextextended(_shop_id::text,1));\n  IF jsonb_array_length(_items)=0 THEN RAISE EXCEPTION ''No sale items''; END IF;\n  FOR it IN SELECT * FROM jsonb_array_elements(_items) LOOP\n    IF (it->>''qty'')::numeric IS NULL OR (it->>''qty'')::numeric <= 0 OR (it->>''price'')::numeric IS NULL OR (it->>''price'')::numeric < 0 THEN RAISE EXCEPTION ''Invalid quantity or rate''; END IF;\n    IF NULLIF(it->>''product_id'','''') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.products WHERE id=(it->>''product_id'')::uuid AND shop_id=_shop_id AND is_active) THEN RAISE EXCEPTION ''Product unavailable in this shop''; END IF;\n  END LOOP;\n  SELECT COALESCE(MAX(bill_no),0)+1');
 EXECUTE d;
 SELECT pg_get_functiondef(oid) INTO d FROM pg_proc WHERE oid='public.create_purchase(uuid,jsonb,numeric,uuid,text,text)'::regprocedure;
 d:=replace(d,'FOR it IN SELECT * FROM jsonb_array_elements(_items) LOOP',E'PERFORM set_config(''app.stock_operation'',''purchase'',true);\n  FOR it IN SELECT * FROM jsonb_array_elements(_items) LOOP');
 EXECUTE d;
END $$;
REVOKE ALL ON FUNCTION public.set_negative_stock_policy(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.set_negative_stock_policy(uuid,boolean) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.inventory_audit(_shop_id uuid) RETURNS TABLE(product_id uuid,product_name text,unit public.unit_type,current_stock numeric,recorded_change numeric,movement_count bigint) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT p.id,p.name,p.unit,p.stock,COALESCE(sum(m.change),0),count(m.id) FROM public.products p LEFT JOIN public.stock_movements m ON m.product_id=p.id AND m.shop_id=p.shop_id WHERE p.shop_id=_shop_id AND public.is_shop_member(_shop_id) GROUP BY p.id;
$$;
REVOKE ALL ON FUNCTION public.inventory_audit(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventory_audit(uuid) TO authenticated,service_role;