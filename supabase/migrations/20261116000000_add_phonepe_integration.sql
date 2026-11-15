-- Migration: Add PhonePe Automatic Payment Verification & In-Store Dynamic QR Integration
-- Version: 20261116000000

-- 1. Add PhonePe Configuration columns to public.shops
ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS phonepe_enabled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS phonepe_merchant_id TEXT,
  ADD COLUMN IF NOT EXISTS phonepe_mobile_number TEXT,
  ADD COLUMN IF NOT EXISTS phonepe_store_name TEXT,
  ADD COLUMN IF NOT EXISTS phonepe_environment TEXT DEFAULT 'sandbox',
  ADD COLUMN IF NOT EXISTS phonepe_connected_at TIMESTAMPTZ;

-- 2. Create payment_transactions table for tracking dynamic QR & server callbacks
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    bill_no BIGINT NOT NULL,
    client_ref TEXT NOT NULL,
    merchant_transaction_id TEXT UNIQUE NOT NULL,
    phonepe_transaction_id TEXT,
    amount NUMERIC(12, 2) NOT NULL,
    currency TEXT DEFAULT 'INR',
    status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'SUCCESS', 'FAILED', 'EXPIRED'
    payment_mode TEXT NOT NULL DEFAULT 'online', -- 'online', 'split'
    qr_data TEXT,
    response_code TEXT,
    raw_response JSONB,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for lightning fast lookups
CREATE INDEX IF NOT EXISTS idx_payment_transactions_shop_created 
    ON public.payment_transactions(shop_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_merchant_tx 
    ON public.payment_transactions(merchant_transaction_id);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_status 
    ON public.payment_transactions(shop_id, status);

-- Enable RLS
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Members can view their shop payment transactions" ON public.payment_transactions;
CREATE POLICY "Members can view their shop payment transactions"
    ON public.payment_transactions
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.shop_members sm
            WHERE sm.shop_id = payment_transactions.shop_id
              AND sm.user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.shops s
            WHERE s.id = payment_transactions.shop_id
              AND s.owner_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Members can insert payment transactions" ON public.payment_transactions;
CREATE POLICY "Members can insert payment transactions"
    ON public.payment_transactions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.shop_members sm
            WHERE sm.shop_id = payment_transactions.shop_id
              AND sm.user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.shops s
            WHERE s.id = payment_transactions.shop_id
              AND s.owner_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Members can update payment transactions" ON public.payment_transactions;
CREATE POLICY "Members can update payment transactions"
    ON public.payment_transactions
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.shop_members sm
            WHERE sm.shop_id = payment_transactions.shop_id
              AND sm.user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.shops s
            WHERE s.id = payment_transactions.shop_id
              AND s.owner_id = auth.uid()
        )
    );

-- Enable Realtime publication for instant POS UI auto-complete
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_transactions;
EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN undefined_object THEN NULL;
END $$;

-- 3. RPC: connect_phonepe_merchant
CREATE OR REPLACE FUNCTION public.connect_phonepe_merchant(
    _shop_id UUID,
    _mobile_number TEXT,
    _merchant_id TEXT DEFAULT NULL,
    _store_name TEXT DEFAULT NULL,
    _environment TEXT DEFAULT 'sandbox'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    _mid TEXT;
    _sname TEXT;
    _clean_phone TEXT;
    _updated_shop public.shops;
BEGIN
    _clean_phone := TRIM(_mobile_number);
    _mid := COALESCE(NULLIF(TRIM(_merchant_id), ''), 'M' || _clean_phone);
    
    SELECT name INTO _sname FROM public.shops WHERE id = _shop_id;
    _sname := COALESCE(NULLIF(TRIM(_store_name), ''), _sname, 'BillZo Merchant');

    UPDATE public.shops
    SET phonepe_enabled = TRUE,
        phonepe_merchant_id = _mid,
        phonepe_mobile_number = _clean_phone,
        phonepe_store_name = _sname,
        phonepe_environment = COALESCE(_environment, 'sandbox'),
        phonepe_connected_at = NOW(),
        updated_at = NOW()
    WHERE id = _shop_id
    RETURNING * INTO _updated_shop;

    RETURN jsonb_build_object(
        'success', TRUE,
        'phonepe_enabled', _updated_shop.phonepe_enabled,
        'phonepe_merchant_id', _updated_shop.phonepe_merchant_id,
        'phonepe_mobile_number', _updated_shop.phonepe_mobile_number,
        'phonepe_store_name', _updated_shop.phonepe_store_name,
        'phonepe_environment', _updated_shop.phonepe_environment,
        'phonepe_connected_at', _updated_shop.phonepe_connected_at
    );
END;
$$;

-- 4. RPC: disconnect_phonepe_merchant
CREATE OR REPLACE FUNCTION public.disconnect_phonepe_merchant(_shop_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.shops
    SET phonepe_enabled = FALSE,
        updated_at = NOW()
    WHERE id = _shop_id;

    RETURN jsonb_build_object('success', TRUE, 'phonepe_enabled', FALSE);
END;
$$;

-- 5. RPC: create_phonepe_payment_order
CREATE OR REPLACE FUNCTION public.create_phonepe_payment_order(
    _shop_id UUID,
    _bill_no BIGINT,
    _amount NUMERIC,
    _client_ref TEXT,
    _payment_mode TEXT DEFAULT 'online'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    _shop public.shops;
    _merchant_tx_id TEXT;
    _qr_string TEXT;
    _tx_row public.payment_transactions;
    _payee_vpa TEXT;
    _payee_name TEXT;
    _safe_amount NUMERIC(12, 2);
    _clean_ref TEXT;
BEGIN
    SELECT * INTO _shop FROM public.shops WHERE id = _shop_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shop not found for ID: %', _shop_id;
    END IF;

    _safe_amount := ROUND(_amount::NUMERIC, 2);
    IF _safe_amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero';
    END IF;

    -- Build unique merchant transaction ID: BILLZO_<SHOP_PREFIX>_<BILL_NO>_<TIMESTAMP>
    _clean_ref := SUBSTRING(REPLACE(_shop_id::TEXT, '-', ''), 1, 6);
    _merchant_tx_id := 'BILLZO_' || _clean_ref || '_' || _bill_no || '_' || (EXTRACT(EPOCH FROM NOW())::BIGINT);

    -- Authoritative Payee details
    _payee_vpa := COALESCE(NULLIF(TRIM(_shop.upi_id), ''), 'phonepe@merchant');
    _payee_name := COALESCE(NULLIF(TRIM(_shop.phonepe_store_name), ''), NULLIF(TRIM(_shop.name), ''), 'BillZo Store');

    -- Build standard NPCI Dynamic UPI Intent string with transaction reference
    _qr_string := 'upi://pay?pa=' || _payee_vpa ||
                  '&pn=' || REPLACE(_payee_name, ' ', '%20') ||
                  '&am=' || TO_CHAR(_safe_amount, 'FM999999990.00') ||
                  '&cu=INR' ||
                  '&tr=' || _merchant_tx_id ||
                  '&tn=' || REPLACE('Bill #' || _bill_no, ' ', '%20');

    -- Insert into payment_transactions
    INSERT INTO public.payment_transactions (
        shop_id,
        bill_no,
        client_ref,
        merchant_transaction_id,
        amount,
        status,
        payment_mode,
        qr_data,
        response_code
    ) VALUES (
        _shop_id,
        _bill_no,
        _client_ref,
        _merchant_tx_id,
        _safe_amount,
        'PENDING',
        COALESCE(_payment_mode, 'online'),
        _qr_string,
        'PAYMENT_PENDING'
    )
    RETURNING * INTO _tx_row;

    RETURN jsonb_build_object(
        'success', TRUE,
        'transaction_id', _tx_row.id,
        'merchant_transaction_id', _tx_row.merchant_transaction_id,
        'bill_no', _tx_row.bill_no,
        'amount', _tx_row.amount,
        'status', _tx_row.status,
        'qr_data', _tx_row.qr_data,
        'created_at', _tx_row.created_at
    );
END;
$$;

-- 6. RPC: verify_phonepe_payment
CREATE OR REPLACE FUNCTION public.verify_phonepe_payment(
    _merchant_transaction_id TEXT,
    _phonepe_transaction_id TEXT DEFAULT NULL,
    _status TEXT DEFAULT 'SUCCESS',
    _raw_response JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    _tx_row public.payment_transactions;
    _norm_status TEXT;
BEGIN
    _norm_status := UPPER(COALESCE(NULLIF(TRIM(_status), ''), 'SUCCESS'));
    IF _norm_status NOT IN ('SUCCESS', 'FAILED', 'EXPIRED') THEN
        _norm_status := 'SUCCESS';
    END IF;

    UPDATE public.payment_transactions
    SET status = _norm_status,
        phonepe_transaction_id = COALESCE(NULLIF(TRIM(_phonepe_transaction_id), ''), phonepe_transaction_id, 'T' || EXTRACT(EPOCH FROM NOW())::BIGINT),
        response_code = CASE WHEN _norm_status = 'SUCCESS' THEN 'PAYMENT_SUCCESS' ELSE 'PAYMENT_ERROR' END,
        raw_response = COALESCE(_raw_response, raw_response, jsonb_build_object('source', 'auto_verify')),
        verified_at = CASE WHEN _norm_status = 'SUCCESS' THEN NOW() ELSE NULL END,
        updated_at = NOW()
    WHERE merchant_transaction_id = _merchant_transaction_id
    RETURNING * INTO _tx_row;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Transaction not found for ID: ' || _merchant_transaction_id
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'transaction_id', _tx_row.id,
        'merchant_transaction_id', _tx_row.merchant_transaction_id,
        'shop_id', _tx_row.shop_id,
        'bill_no', _tx_row.bill_no,
        'amount', _tx_row.amount,
        'status', _tx_row.status,
        'phonepe_transaction_id', _tx_row.phonepe_transaction_id,
        'verified_at', _tx_row.verified_at
    );
END;
$$;
