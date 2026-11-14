-- Migration: 20261115000000_professional_offline_first_schema.sql
-- Description: Phase 2 Safe Schema Migration for Enterprise Offline-First POS Architecture.
-- 100% Non-destructive, Idempotent, and fully backward-compatible with existing data.

-- ============================================================================
-- 1. FIRST-CLASS CATEGORIES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  name text NOT NULL,
  image_url text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_categories_shop_name UNIQUE (shop_id, name)
);

-- Backfill categories from existing products table
INSERT INTO public.categories (shop_id, name)
SELECT DISTINCT p.shop_id, TRIM(p.category)
FROM public.products p
WHERE p.category IS NOT NULL 
  AND TRIM(p.category) <> '' 
  AND LOWER(TRIM(p.category)) <> 'all'
ON CONFLICT ON CONSTRAINT uq_categories_shop_name DO NOTHING;

-- Add category_id foreign key column to products (keeping category text for backwards compatibility)
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL;

-- Link existing products to the newly backfilled categories
UPDATE public.products p
SET category_id = c.id
FROM public.categories c
WHERE p.shop_id = c.shop_id 
  AND LOWER(TRIM(p.category)) = LOWER(TRIM(c.name))
  AND p.category_id IS NULL;

-- RLS & Grants for categories
GRANT SELECT, INSERT, UPDATE, DELETE ON public.categories TO authenticated;
GRANT ALL ON public.categories TO service_role;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'categories' AND policyname = 'shop members read categories') THEN
    CREATE POLICY "shop members read categories" ON public.categories FOR SELECT TO authenticated USING (public.is_shop_member(shop_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'categories' AND policyname = 'shop members insert categories') THEN
    CREATE POLICY "shop members insert categories" ON public.categories FOR INSERT TO authenticated WITH CHECK (public.is_shop_member(shop_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'categories' AND policyname = 'shop members update categories') THEN
    CREATE POLICY "shop members update categories" ON public.categories FOR UPDATE TO authenticated USING (public.is_shop_member(shop_id)) WITH CHECK (public.is_shop_member(shop_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'categories' AND policyname = 'shop members delete categories') THEN
    CREATE POLICY "shop members delete categories" ON public.categories FOR DELETE TO authenticated USING (public.is_shop_member(shop_id));
  END IF;
END $$;

DROP TRIGGER IF EXISTS categories_updated ON public.categories;
CREATE TRIGGER categories_updated BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 2. ATOMIC BILL COUNTERS (Zero Duplicate Invoice Numbers)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shop_bill_counters (
  shop_id uuid PRIMARY KEY REFERENCES public.shops(id) ON DELETE CASCADE,
  last_bill_no integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Backfill shop_bill_counters from highest existing bill number per shop
INSERT INTO public.shop_bill_counters (shop_id, last_bill_no)
SELECT s.id, COALESCE(MAX(b.bill_no), 0)
FROM public.shops s
LEFT JOIN public.sales b ON b.shop_id = s.id
GROUP BY s.id
ON CONFLICT (shop_id) DO UPDATE
SET last_bill_no = GREATEST(shop_bill_counters.last_bill_no, EXCLUDED.last_bill_no);

-- Security & RLS for bill counters
GRANT SELECT ON public.shop_bill_counters TO authenticated;
GRANT ALL ON public.shop_bill_counters TO service_role;
ALTER TABLE public.shop_bill_counters ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'shop_bill_counters' AND policyname = 'shop members read bill counters') THEN
    CREATE POLICY "shop members read bill counters" ON public.shop_bill_counters FOR SELECT TO authenticated USING (public.is_shop_member(shop_id));
  END IF;
END $$;

-- Atomic RPC function to allocate next sequential bill number per shop
CREATE OR REPLACE FUNCTION public.get_next_bill_no(_shop_id uuid)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _next integer;
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN
    RAISE EXCEPTION 'not authorized for this shop';
  END IF;

  INSERT INTO public.shop_bill_counters (shop_id, last_bill_no)
  VALUES (_shop_id, 1)
  ON CONFLICT (shop_id) DO UPDATE
  SET last_bill_no = shop_bill_counters.last_bill_no + 1,
      updated_at = now()
  RETURNING last_bill_no INTO _next;

  RETURN _next;
END; $$;
REVOKE ALL ON FUNCTION public.get_next_bill_no(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_next_bill_no(uuid) TO authenticated;


-- ============================================================================
-- 3. IMMUTABLE CUSTOMER LEDGER (Audit-Proof Khata Accounting)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.customer_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  entry_type text NOT NULL, -- 'opening_balance', 'credit_sale', 'payment', 'return', 'adjustment'
  amount numeric(12,2) NOT NULL DEFAULT 0,
  balance_after numeric(12,2) NOT NULL DEFAULT 0,
  sale_id uuid REFERENCES public.sales(id) ON DELETE SET NULL,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  note text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Backfill existing customer balances into ledger as opening balances
INSERT INTO public.customer_ledger (shop_id, customer_id, entry_type, amount, balance_after, note)
SELECT c.shop_id, c.id, 'opening_balance', c.balance, c.balance, 'Initial balance from customer profile'
FROM public.customers c
WHERE c.balance > 0
  AND NOT EXISTS (
    SELECT 1 FROM public.customer_ledger l WHERE l.customer_id = c.id
  );

-- RLS & Grants for customer_ledger
GRANT SELECT, INSERT ON public.customer_ledger TO authenticated;
GRANT ALL ON public.customer_ledger TO service_role;
ALTER TABLE public.customer_ledger ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'customer_ledger' AND policyname = 'shop members read customer_ledger') THEN
    CREATE POLICY "shop members read customer_ledger" ON public.customer_ledger FOR SELECT TO authenticated USING (public.is_shop_member(shop_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'customer_ledger' AND policyname = 'shop members insert customer_ledger') THEN
    CREATE POLICY "shop members insert customer_ledger" ON public.customer_ledger FOR INSERT TO authenticated WITH CHECK (public.is_shop_member(shop_id));
  END IF;
END $$;

-- Atomic RPC: Record Customer Due Collection with Immutable Ledger entry
CREATE OR REPLACE FUNCTION public.record_customer_payment(
  _shop_id uuid,
  _customer_id uuid,
  _amount numeric,
  _mode public.payment_mode,
  _note text DEFAULT 'Due payment'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _payment_id uuid;
  _old_bal numeric(12,2);
  _new_bal numeric(12,2);
  _ledger_id uuid;
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN
    RAISE EXCEPTION 'not authorized for this shop';
  END IF;

  SELECT balance INTO _old_bal FROM public.customers
  WHERE id = _customer_id AND shop_id = _shop_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'customer not found in this shop';
  END IF;

  _new_bal := GREATEST(0, _old_bal - _amount);

  -- 1. Insert into payments table
  INSERT INTO public.payments (shop_id, customer_id, amount, mode, note, created_by)
  VALUES (_shop_id, _customer_id, _amount, _mode, _note, auth.uid())
  RETURNING id INTO _payment_id;

  -- 2. Insert into immutable customer_ledger
  INSERT INTO public.customer_ledger (shop_id, customer_id, entry_type, amount, balance_after, payment_id, note, created_by)
  VALUES (_shop_id, _customer_id, 'payment', _amount, _new_bal, _payment_id, _note, auth.uid())
  RETURNING id INTO _ledger_id;

  -- 3. Atomically update customer balance
  UPDATE public.customers
  SET balance = _new_bal, updated_at = now()
  WHERE id = _customer_id AND shop_id = _shop_id;

  RETURN jsonb_build_object(
    'payment_id', _payment_id,
    'ledger_id', _ledger_id,
    'previous_balance', _old_bal,
    'new_balance', _new_bal
  );
END; $$;
REVOKE ALL ON FUNCTION public.record_customer_payment(uuid,uuid,numeric,public.payment_mode,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_customer_payment(uuid,uuid,numeric,public.payment_mode,text) TO authenticated;


-- ============================================================================
-- 4. SALES UPDATED_AT & ADVANCED CREATE_SALE RPC
-- ============================================================================
-- Ensure sales table has updated_at for Delta Sync
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DROP TRIGGER IF EXISTS sales_updated ON public.sales;
CREATE TRIGGER sales_updated BEFORE UPDATE ON public.sales FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Upgrade create_sale RPC to use atomic bill numbering and write to customer_ledger
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
  it jsonb;
BEGIN
  IF NOT public.is_shop_member(_shop_id) THEN
    RAISE EXCEPTION 'not authorized for this shop';
  END IF;

  -- Allocate atomic bill number safely
  _bill_no := public.get_next_bill_no(_shop_id);

  FOR it IN SELECT * FROM jsonb_array_elements(_items) LOOP
    _sub := _sub + ((it->>'price')::numeric * (it->>'qty')::numeric);
  END LOOP;

  _total := GREATEST(0, _sub - COALESCE(_discount,0));
  _due := GREATEST(0, _total - COALESCE(_paid,0));

  INSERT INTO public.sales (shop_id, bill_no, customer_id, customer_name, customer_phone,
    sub_total, discount, total, paid, due, payment_mode, note, created_by, updated_at)
  VALUES (_shop_id, _bill_no, _customer_id, _customer_name, _customer_phone,
    _sub, COALESCE(_discount,0), _total, COALESCE(_paid,0), _due, _payment_mode, _note, auth.uid(), now())
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
END; $$;


-- ============================================================================
-- 5. HIGH-PERFORMANCE COMPOSITE INDEXES FOR DELTA SYNCHRONIZATION
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_products_shop_updated ON public.products (shop_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_sales_shop_updated ON public.sales (shop_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_customers_shop_updated ON public.customers (shop_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_categories_shop_updated ON public.categories (shop_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_customer_ledger_shop_customer ON public.customer_ledger (shop_id, customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_shop_created ON public.stock_movements (shop_id, created_at DESC);
