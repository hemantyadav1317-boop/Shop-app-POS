-- Add credit_limit to customers table
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS credit_limit numeric(12,2) DEFAULT 0;
