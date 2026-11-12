-- Add Google Maps Review URL to shops table for verified bill QR code
ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS google_review_url text;

