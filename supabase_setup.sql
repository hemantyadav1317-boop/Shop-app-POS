-- =========================================================
-- COMPLETE IDEMPOTENT SUPABASE SETUP SCRIPT
-- Safe to run multiple times without any "already exists" errors
-- =========================================================

-- ===== 1. ENUMS =====
DO $$ BEGIN
  CREATE TYPE public.shop_role AS ENUM ('owner','manager','cashier');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.unit_type AS ENUM ('kg','pc');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.payment_mode AS ENUM ('cash','online','credit','split','set_later');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.stock_reason AS ENUM ('sale','purchase','adjustment','return','opening');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ===== 2. HELPER FUNCTIONS =====
CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS TRIGGER
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

-- ===== 3. PROFILES =====
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY,
  email text,
  full_name text,
  avatar_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own profile read" ON public.profiles;
CREATE POLICY "own profile read" ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid());

DROP POLICY IF EXISTS "own profile write" ON public.profiles;
CREATE POLICY "own profile write" ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "own profile insert" ON public.profiles;
CREATE POLICY "own profile insert" ON public.profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());

DROP TRIGGER IF EXISTS profiles_updated ON public.profiles;
CREATE TRIGGER profiles_updated BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (NEW.id, NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(COALESCE(NEW.email,''),'@',1)),
    NEW.raw_user_meta_data->>'avatar_url')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ===== 4. SHOPS & MEMBERS =====
CREATE TABLE IF NOT EXISTS public.shops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  name text NOT NULL,
  phone text,
  address text,
  currency text NOT NULL DEFAULT 'Rs',
  gst_number text,
  bill_prefix text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS upi_id text;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS upi_payee_name text;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS qr_image_url text;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS allow_negative_stock boolean DEFAULT false;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS print_paper_size text DEFAULT '58mm';
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS receipt_footer text DEFAULT 'धन्यवाद! फिर पधारें 🙏';

CREATE TABLE IF NOT EXISTS public.shop_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  role public.shop_role NOT NULL DEFAULT 'cashier',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (shop_id, user_id)
);

CREATE OR REPLACE FUNCTION public.is_shop_member(_shop_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.shop_members m WHERE m.shop_id = _shop_id AND m.user_id = auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.has_shop_role(_shop_id uuid, _roles public.shop_role[]) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.shop_members m WHERE m.shop_id = _shop_id AND m.user_id = auth.uid() AND m.role = ANY(_roles));
$$;

CREATE OR REPLACE FUNCTION public.is_shop_owner(_shop_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.shops s WHERE s.id = _shop_id AND s.owner_id = auth.uid());
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.shops TO authenticated;
GRANT ALL ON public.shops TO service_role;
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members read shop" ON public.shops;
CREATE POLICY "members read shop" ON public.shops FOR SELECT TO authenticated USING (public.is_shop_member(id));

DROP POLICY IF EXISTS "create own shop" ON public.shops;
CREATE POLICY "create own shop" ON public.shops FOR INSERT TO authenticated WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "owner updates shop" ON public.shops;
CREATE POLICY "owner updates shop" ON public.shops FOR UPDATE TO authenticated USING (public.has_shop_role(id, ARRAY['owner','manager']::public.shop_role[])) WITH CHECK (true);

DROP POLICY IF EXISTS "owner deletes shop" ON public.shops;
CREATE POLICY "owner deletes shop" ON public.shops FOR DELETE TO authenticated USING (owner_id = auth.uid());

DROP TRIGGER IF EXISTS shops_updated ON public.shops;
CREATE TRIGGER shops_updated BEFORE UPDATE ON public.shops FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

GRANT SELECT, INSERT, UPDATE, DELETE ON public.shop_members TO authenticated;
GRANT ALL ON public.shop_members TO service_role;
ALTER TABLE public.shop_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members read members" ON public.shop_members;
CREATE POLICY "members read members" ON public.shop_members FOR SELECT TO authenticated USING (public.is_shop_member(shop_id) OR user_id = auth.uid());

DROP POLICY IF EXISTS "self join as owner" ON public.shop_members;
CREATE POLICY "self join as owner" ON public.shop_members FOR INSERT TO authenticated
WITH CHECK (
  ((user_id = auth.uid()) AND public.is_shop_owner(shop_id))
  OR public.has_shop_role(shop_id, ARRAY['owner'::public.shop_role, 'manager'::public.shop_role])
);

DROP POLICY IF EXISTS "owner manages members" ON public.shop_members;
CREATE POLICY "owner manages members" ON public.shop_members FOR UPDATE TO authenticated USING (public.has_shop_role(shop_id, ARRAY['owner','manager']::public.shop_role[])) WITH CHECK (true);

DROP POLICY IF EXISTS "owner removes members" ON public.shop_members;
CREATE POLICY "owner removes members" ON public.shop_members FOR DELETE TO authenticated USING (public.has_shop_role(shop_id, ARRAY['owner']::public.shop_role[]));

-- ===== 5. SHOP-SCOPED TABLES =====
CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  name text NOT NULL,
  category text NOT NULL DEFAULT 'General',
  unit public.unit_type NOT NULL DEFAULT 'kg',
  price numeric(12,2) NOT NULL DEFAULT 0,
  cost_price numeric(12,2) NOT NULL DEFAULT 0,
  stock numeric(12,3) NOT NULL DEFAULT 0,
  low_stock_at numeric(12,3) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  image_url text,
  barcode text,
  sku text,
  name_en text,
  name_hi text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure image_url column exists if table was created previously
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url text;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS barcode text;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS sku text;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS name_en text;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS name_hi text;

CREATE TABLE IF NOT EXISTS public.customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text,
  address text,
  balance numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.vendors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text,
  address text,
  payable numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  bill_no integer NOT NULL,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  customer_name text,
  customer_phone text,
  sub_total numeric(12,2) NOT NULL DEFAULT 0,
  discount numeric(12,2) NOT NULL DEFAULT 0,
  tax numeric(12,2) NOT NULL DEFAULT 0,
  total numeric(12,2) NOT NULL DEFAULT 0,
  paid numeric(12,2) NOT NULL DEFAULT 0,
  due numeric(12,2) NOT NULL DEFAULT 0,
  payment_mode public.payment_mode NOT NULL DEFAULT 'cash',
  note text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (shop_id, bill_no)
);

CREATE TABLE IF NOT EXISTS public.sale_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  name text NOT NULL,
  unit public.unit_type NOT NULL DEFAULT 'kg',
  price numeric(12,2) NOT NULL DEFAULT 0,
  qty numeric(12,3) NOT NULL DEFAULT 0,
  line_total numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  sale_id uuid REFERENCES public.sales(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  amount numeric(12,2) NOT NULL DEFAULT 0,
  mode public.payment_mode NOT NULL DEFAULT 'cash',
  note text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.purchases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  vendor_id uuid REFERENCES public.vendors(id) ON DELETE SET NULL,
  vendor_name text,
  total numeric(12,2) NOT NULL DEFAULT 0,
  paid numeric(12,2) NOT NULL DEFAULT 0,
  due numeric(12,2) NOT NULL DEFAULT 0,
  note text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.purchase_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  purchase_id uuid NOT NULL REFERENCES public.purchases(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  name text NOT NULL,
  qty numeric(12,3) NOT NULL DEFAULT 0,
  cost numeric(12,2) NOT NULL DEFAULT 0,
  line_total numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  category text NOT NULL DEFAULT 'General',
  amount numeric(12,2) NOT NULL DEFAULT 0,
  note text,
  spent_on date NOT NULL DEFAULT (now()::date),
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stock_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
  change numeric(12,3) NOT NULL DEFAULT 0,
  reason public.stock_reason NOT NULL DEFAULT 'adjustment',
  ref_id uuid,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.saved_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  label text,
  customer_name text,
  customer_phone text,
  lines jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Loop for RLS on shop tables
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

DROP TRIGGER IF EXISTS products_updated ON public.products;
CREATE TRIGGER products_updated BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS customers_updated ON public.customers;
CREATE TRIGGER customers_updated BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS vendors_updated ON public.vendors;
CREATE TRIGGER vendors_updated BEFORE UPDATE ON public.vendors FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_products_shop_active ON public.products (shop_id, is_active);
CREATE INDEX IF NOT EXISTS idx_sales_shop_created ON public.sales (shop_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON public.sale_items (sale_id);
CREATE INDEX IF NOT EXISTS idx_expenses_shop_spent ON public.expenses (shop_id, spent_on);
CREATE INDEX IF NOT EXISTS idx_stock_movements_shop_prod ON public.stock_movements (shop_id, product_id);

-- ===== 6. TRANSACTIONAL RPC FUNCTIONS =====
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
  it jsonb;
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN
    RAISE EXCEPTION 'not authorized for this shop';
  END IF;

  SELECT COALESCE(MAX(bill_no),0)+1 INTO _bill_no FROM public.sales WHERE shop_id = _shop_id;

  FOR it IN SELECT * FROM jsonb_array_elements(_items) LOOP
    _sub := _sub + ((it->>'price')::numeric * (it->>'qty')::numeric);
  END LOOP;

  _total := GREATEST(0, _sub - COALESCE(_discount,0));
  _due := GREATEST(0, _total - COALESCE(_paid,0));

  INSERT INTO public.sales (shop_id, bill_no, customer_id, customer_name, customer_phone,
    sub_total, discount, total, paid, due, payment_mode, note, created_by)
  VALUES (_shop_id, _bill_no, _customer_id, _customer_name, _customer_phone,
    _sub, COALESCE(_discount,0), _total, COALESCE(_paid,0), _due, _payment_mode, _note, auth.uid())
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
    UPDATE public.customers SET balance = balance + _due WHERE id = _customer_id AND shop_id = _shop_id;
  END IF;

  RETURN _sale_id;
END; $$;

CREATE OR REPLACE FUNCTION public.create_purchase(
  _shop_id uuid, _items jsonb, _paid numeric, _vendor_id uuid, _vendor_name text, _note text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _pid uuid; _total numeric(12,2) := 0; _due numeric(12,2); it jsonb;
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN RAISE EXCEPTION 'not authorized for this shop'; END IF;
  FOR it IN SELECT * FROM jsonb_array_elements(_items) LOOP
    _total := _total + ((it->>'cost')::numeric * (it->>'qty')::numeric);
  END LOOP;
  _due := GREATEST(0, _total - COALESCE(_paid,0));
  INSERT INTO public.purchases (shop_id, vendor_id, vendor_name, total, paid, due, note, created_by)
  VALUES (_shop_id, _vendor_id, _vendor_name, _total, COALESCE(_paid,0), _due, _note, auth.uid())
  RETURNING id INTO _pid;

  FOR it IN SELECT * FROM jsonb_array_elements(_items) LOOP
    INSERT INTO public.purchase_items (shop_id, purchase_id, product_id, name, qty, cost, line_total)
    VALUES (_shop_id, _pid, NULLIF(it->>'product_id','')::uuid, it->>'name',
      (it->>'qty')::numeric, (it->>'cost')::numeric, (it->>'cost')::numeric * (it->>'qty')::numeric);
    IF NULLIF(it->>'product_id','') IS NOT NULL THEN
      UPDATE public.products SET stock = stock + (it->>'qty')::numeric, cost_price = (it->>'cost')::numeric
      WHERE id = (it->>'product_id')::uuid AND shop_id = _shop_id;
      INSERT INTO public.stock_movements (shop_id, product_id, change, reason, ref_id)
      VALUES (_shop_id, (it->>'product_id')::uuid, (it->>'qty')::numeric, 'purchase', _pid);
    END IF;
  END LOOP;

  IF _due > 0 AND _vendor_id IS NOT NULL THEN
    UPDATE public.vendors SET payable = payable + _due WHERE id = _vendor_id AND shop_id = _shop_id;
  END IF;
  RETURN _pid;
END; $$;

CREATE OR REPLACE FUNCTION public.collect_due(_shop_id uuid, _customer_id uuid, _amount numeric, _mode public.payment_mode)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN RAISE EXCEPTION 'not authorized for this shop'; END IF;
  INSERT INTO public.payments (shop_id, customer_id, amount, mode, note, created_by)
  VALUES (_shop_id, _customer_id, _amount, _mode, 'Due collection', auth.uid());
  UPDATE public.customers SET balance = GREATEST(0, balance - _amount) WHERE id = _customer_id AND shop_id = _shop_id;
END; $$;

-- Permissions
REVOKE ALL ON FUNCTION public.is_shop_member(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_shop_role(uuid, public.shop_role[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_updated_at() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_sale(uuid,jsonb,numeric,public.payment_mode,numeric,uuid,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_purchase(uuid,jsonb,numeric,uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.collect_due(uuid,uuid,numeric,public.payment_mode) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_shop_owner(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.is_shop_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_shop_role(uuid, public.shop_role[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_shop_owner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_sale(uuid,jsonb,numeric,public.payment_mode,numeric,uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_purchase(uuid,jsonb,numeric,uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.collect_due(uuid,uuid,numeric,public.payment_mode) TO authenticated;
