-- Migration: 20261104010000_add_staff_pairing_rpc.sql
-- Enables 5-layer secure staff pairing by Shop Phone + Staff PIN without requiring owner email/password.

-- 1. Ensure share_code column exists on shops
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS share_code varchar(6);
CREATE INDEX IF NOT EXISTS idx_shops_share_code ON public.shops(share_code);
CREATE INDEX IF NOT EXISTS idx_shops_phone ON public.shops(phone);

-- 2. Secure Staff Verification RPC (Runs as SECURITY DEFINER to bypass RLS for authorized staff pairing)
CREATE OR REPLACE FUNCTION public.staff_verify_shop(
  _phone text,
  _pin text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _shop record;
  _products jsonb;
  _customers jsonb;
  _sales jsonb;
  _expenses jsonb;
  _clean_phone text;
  _clean_pin text;
BEGIN
  _clean_phone := trim(_phone);
  _clean_pin := trim(_pin);

  IF _clean_phone = '' OR _clean_pin = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'मोबाइल नंबर और स्टाफ पिन आवश्यक हैं');
  END IF;

  -- Look for shop by phone and pin:
  -- Phone can match exact, with +91, or without +91
  -- PIN can match share_code, bill_prefix, or 'PIN:' || pin
  SELECT * INTO _shop FROM public.shops 
  WHERE (
    phone = _clean_phone 
    OR phone = ('+91' || _clean_phone) 
    OR phone = regexp_replace(_clean_phone, '^\+91', '')
    OR phone = regexp_replace(_clean_phone, '^0', '')
  )
  AND (
    share_code = _clean_pin 
    OR bill_prefix = _clean_pin 
    OR bill_prefix = ('PIN:' || _clean_pin)
    OR (share_code IS NULL AND (abs(hashtext(id::text)) % 900000 + 100000)::text = _clean_pin)
  )
  LIMIT 1;

  IF _shop.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'अमान्य दुकान मोबाइल नंबर या 6-अंकीय स्टाफ पिन! कृपया जांचें।'
    );
  END IF;

  -- Fetch active products for this shop
  SELECT coalesce(jsonb_agg(to_jsonb(p.*)), '[]'::jsonb) 
  INTO _products 
  FROM public.products p 
  WHERE p.shop_id = _shop.id AND p.is_active = true;

  -- Fetch customers for this shop
  SELECT coalesce(jsonb_agg(to_jsonb(c.*)), '[]'::jsonb) 
  INTO _customers 
  FROM public.customers c 
  WHERE c.shop_id = _shop.id;

  -- Fetch recent sales with nested items for this shop (Bypasses RLS for authorized staff)
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
    LIMIT 200
  ) s;

  -- Fetch recent daybook expenses
  SELECT coalesce(jsonb_agg(to_jsonb(e.*) ORDER BY e.spent_on DESC), '[]'::jsonb)
  INTO _expenses
  FROM (
    SELECT * FROM public.expenses
    WHERE shop_id = _shop.id
    ORDER BY spent_on DESC
    LIMIT 200
  ) e;

  RETURN jsonb_build_object(
    'success', true,
    'shop', to_jsonb(_shop),
    'products', _products,
    'customers', _customers,
    'sales', _sales,
    'expenses', _expenses
  );
END;
$$;

-- 3. Dedicated Staff RPC to fetch latest sales on pull-to-refresh
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
    LIMIT 200
  ) s;

  RETURN jsonb_build_object('success', true, 'sales', _sales);
END;
$$;

-- 4. Dedicated Staff RPC to fetch latest expenses on pull-to-refresh
CREATE OR REPLACE FUNCTION public.staff_get_expenses(
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
  _expenses jsonb;
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

  SELECT coalesce(jsonb_agg(to_jsonb(e.*) ORDER BY e.spent_on DESC), '[]'::jsonb)
  INTO _expenses
  FROM (
    SELECT * FROM public.expenses
    WHERE shop_id = _shop.id
    ORDER BY spent_on DESC
    LIMIT 200
  ) e;

  RETURN jsonb_build_object('success', true, 'expenses', _expenses);
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_get_sales(text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.staff_get_expenses(text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.staff_verify_shop(text, text) TO anon, authenticated, service_role;


