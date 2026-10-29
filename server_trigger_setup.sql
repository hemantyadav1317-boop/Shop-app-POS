-- ====================================================================
-- PROFESSIONAL BILLIES/VYAPAR-STYLE SERVER TRIGGER & SCHEMA MIGRATION
-- Run this in Supabase -> SQL Editor -> New Query -> Run
-- ====================================================================

-- 1. मिसिंग कॉलम्स जोड़ें (Add Missing Columns in shops table)
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS upi_id text;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS upi_payee_name text;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS qr_image_url text;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS allow_negative_stock boolean DEFAULT false;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS print_paper_size text DEFAULT '58mm';
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS receipt_footer text DEFAULT 'धन्यवाद! फिर पधारें 🙏';

-- 2. Helper Functions (Security Definer - Super Admin Execution)
CREATE OR REPLACE FUNCTION public.is_shop_member(_shop_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.shop_members m WHERE m.shop_id = _shop_id AND m.user_id = auth.uid()
    UNION
    SELECT 1 FROM public.shops s WHERE s.id = _shop_id AND s.owner_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_shop_member(uuid) TO authenticated, anon, service_role, public;

-- 3. RLS Policies: दुकान मालिक को कभी न रोकें (Direct Owner Access)
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members read shop" ON public.shops;
CREATE POLICY "members read shop" ON public.shops FOR SELECT TO authenticated
USING (owner_id = auth.uid() OR public.is_shop_member(id));

DROP POLICY IF EXISTS "create own shop" ON public.shops;
CREATE POLICY "create own shop" ON public.shops FOR INSERT TO authenticated
WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "owner updates shop" ON public.shops;
CREATE POLICY "owner updates shop" ON public.shops FOR UPDATE TO authenticated
USING (owner_id = auth.uid() OR public.is_shop_member(id))
WITH CHECK (owner_id = auth.uid() OR public.is_shop_member(id));

-- 4. Shop Members Permissions
ALTER TABLE public.shop_members ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.shop_members TO authenticated, service_role;

DROP POLICY IF EXISTS "members access shop_members" ON public.shop_members;
CREATE POLICY "members access shop_members" ON public.shop_members FOR ALL TO authenticated
USING (user_id = auth.uid() OR public.is_shop_member(shop_id))
WITH CHECK (user_id = auth.uid() OR public.is_shop_member(shop_id));

-- 5. Billies/Vyapar जैसा ऑटोमैटिक सर्वर-साइड ट्रिगर (Server-Side Auto Provisioning)
-- जैसे ही कोई भी यूजर Google या Email से रजिस्टर करता है, डेटाबेस खुद उसी मिलीसेकंड में उसकी दुकान बना देगा
CREATE OR REPLACE FUNCTION public.handle_new_user_shop()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  new_shop_id uuid := gen_random_uuid();
  user_name text;
BEGIN
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1),
    'दुकानदार'
  );

  -- नई दुकान बनाएं
  INSERT INTO public.shops (
    id,
    owner_id,
    name,
    currency,
    bill_prefix,
    allow_negative_stock,
    print_paper_size,
    receipt_footer
  )
  VALUES (
    new_shop_id,
    NEW.id,
    'मेरी दुकान (' || user_name || ')',
    'Rs',
    '',
    false,
    '58mm',
    'धन्यवाद! फिर पधारें 🙏'
  )
  ON CONFLICT DO NOTHING;

  -- यूजर को ओनर बनाएं
  INSERT INTO public.shop_members (shop_id, user_id, role)
  VALUES (new_shop_id, NEW.id, 'owner')
  ON CONFLICT (shop_id, user_id) DO NOTHING;

  RETURN NEW;
END; $$;

GRANT EXECUTE ON FUNCTION public.handle_new_user_shop() TO authenticated, anon, service_role, public;

DROP TRIGGER IF EXISTS on_auth_user_created_shop ON auth.users;
CREATE TRIGGER on_auth_user_created_shop AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_shop();

-- 6. सभी मौजूदा यूजर्स के लिए जिनकी अभी तक दुकान नहीं बनी है, तुरंत बना दें
DO $$
DECLARE
  u RECORD;
  new_s_id uuid;
  u_name text;
BEGIN
  FOR u IN SELECT id, email, raw_user_meta_data FROM auth.users LOOP
    IF NOT EXISTS (SELECT 1 FROM public.shops WHERE owner_id = u.id) AND
       NOT EXISTS (SELECT 1 FROM public.shop_members WHERE user_id = u.id) THEN
      new_s_id := gen_random_uuid();
      u_name := COALESCE(
        u.raw_user_meta_data->>'full_name',
        u.raw_user_meta_data->>'name',
        split_part(u.email, '@', 1),
        'दुकानदार'
      );
      INSERT INTO public.shops (id, owner_id, name, currency, bill_prefix, allow_negative_stock, print_paper_size, receipt_footer)
      VALUES (new_s_id, u.id, 'मेरी दुकान (' || u_name || ')', 'Rs', '', false, '58mm', 'धन्यवाद! फिर पधारें 🙏')
      ON CONFLICT DO NOTHING;

      INSERT INTO public.shop_members (shop_id, user_id, role)
      VALUES (new_s_id, u.id, 'owner')
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
END $$;

-- 7. Grant permissions on create_sale & ensure products stock updates are allowed
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_sale') THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.create_sale(uuid,jsonb,numeric,public.payment_mode,numeric,uuid,text,text,text) TO authenticated, anon, service_role, public;';
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- 8. Ensure products update policy allows shop members and owners to update stock
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "members update products" ON public.products;
CREATE POLICY "members update products" ON public.products FOR UPDATE TO authenticated
USING (public.is_shop_member(shop_id))
WITH CHECK (public.is_shop_member(shop_id));


