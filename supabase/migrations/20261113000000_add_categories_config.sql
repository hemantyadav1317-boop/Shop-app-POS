-- Add shop-level categories configuration (custom categories, deleted built-in categories, category images)
-- Safe additive migration for multi-device and offline-cloud category synchronization.
ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS categories_config jsonb DEFAULT '{}'::jsonb;

