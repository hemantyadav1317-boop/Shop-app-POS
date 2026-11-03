-- Add share_code to shops table for 6-digit staff/family sharing
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS share_code varchar(6);

-- Optional: Create index on share_code for instant lookup
CREATE INDEX IF NOT EXISTS idx_shops_share_code ON public.shops(share_code);
