-- ====================================================================
-- SUPABASE CLOUD MULTI-DEVICE DATA SYNC & RLS FIX
-- Paste and run this in Supabase -> SQL Editor -> New Query -> Run
-- ====================================================================

-- 1. Helper function: Returns true if user is owner OR listed in shop_members
CREATE OR REPLACE FUNCTION public.is_shop_member(_shop_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.shop_members m WHERE m.shop_id = _shop_id AND m.user_id = auth.uid()
    UNION
    SELECT 1 FROM public.shops s WHERE s.id = _shop_id AND s.owner_id = auth.uid()
  );
$$;

-- Grant execution permission on functions to all roles
GRANT EXECUTE ON FUNCTION public.is_shop_member(uuid) TO authenticated, anon, service_role, public;

-- 2. Allow shop owners to SELECT, INSERT and UPDATE their shop freely without deadlock
DROP POLICY IF EXISTS "members read shop" ON public.shops;
CREATE POLICY "members read shop" ON public.shops FOR SELECT TO authenticated
USING (owner_id = auth.uid() OR public.is_shop_member(id));

DROP POLICY IF EXISTS "create own shop" ON public.shops;
CREATE POLICY "create own shop" ON public.shops FOR INSERT TO authenticated
WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "owner updates shop" ON public.shops;
CREATE POLICY "owner updates shop" ON public.shops FOR UPDATE TO authenticated
USING (owner_id = auth.uid() OR public.has_shop_role(id, ARRAY['owner','manager']::public.shop_role[]))
WITH CHECK (true);

-- 3. Automatic Trigger: Whenever a shop is created, immediately make owner a member
CREATE OR REPLACE FUNCTION public.handle_new_shop() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.shop_members (shop_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner')
  ON CONFLICT (shop_id, user_id) DO NOTHING;
  RETURN NEW;
END; $$;

GRANT EXECUTE ON FUNCTION public.handle_new_shop() TO authenticated, anon, service_role, public;

DROP TRIGGER IF EXISTS on_shop_created ON public.shops;
CREATE TRIGGER on_shop_created AFTER INSERT ON public.shops
FOR EACH ROW EXECUTE FUNCTION public.handle_new_shop();

-- 3b. Permissions and RLS for shop_members
GRANT ALL ON public.shop_members TO authenticated, service_role;
ALTER TABLE public.shop_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "members access shop_members" ON public.shop_members;
CREATE POLICY "members access shop_members" ON public.shop_members FOR ALL TO authenticated
USING (user_id = auth.uid() OR public.is_shop_member(shop_id))
WITH CHECK (user_id = auth.uid() OR public.is_shop_member(shop_id));

-- 4. Enable seamless SELECT, INSERT, UPDATE, DELETE for all shop data tables
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['products','customers','vendors','sales','sale_items','payments','purchases','purchase_items','expenses','stock_movements','saved_orders']
  LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated;', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role;', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    
    EXECUTE format('DROP POLICY IF EXISTS "shop members read %1$s" ON public.%1$I;', t);
    EXECUTE format('CREATE POLICY "shop members read %1$s" ON public.%1$I FOR SELECT TO authenticated USING (public.is_shop_member(shop_id));', t);
    
    EXECUTE format('DROP POLICY IF EXISTS "shop members insert %1$s" ON public.%1$I;', t);
    EXECUTE format('CREATE POLICY "shop members insert %1$s" ON public.%1$I FOR INSERT TO authenticated WITH CHECK (public.is_shop_member(shop_id));', t);
    
    EXECUTE format('DROP POLICY IF EXISTS "shop members update %1$s" ON public.%1$I;', t);
    EXECUTE format('CREATE POLICY "shop members update %1$s" ON public.%1$I FOR UPDATE TO authenticated USING (public.is_shop_member(shop_id)) WITH CHECK (public.is_shop_member(shop_id));', t);
    
    EXECUTE format('DROP POLICY IF EXISTS "shop members delete %1$s" ON public.%1$I;', t);
    EXECUTE format('CREATE POLICY "shop members delete %1$s" ON public.%1$I FOR DELETE TO authenticated USING (public.is_shop_member(shop_id));', t);
  END LOOP;
END $$;

-- 5. Final Grant for functions and schema access
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO authenticated, service_role;
