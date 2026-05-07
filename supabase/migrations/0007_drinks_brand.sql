-- 0007_drinks_brand.sql
-- Add brand column to drinks (and drinks_pending) so the catalog matches
-- the Type / Brand / Name / Style format used in the UI. Sourcing brand
-- as a separate column lets search hit it cleanly via OR and lets us
-- filter by brand in the picker.

set search_path = public;

alter table drinks add column if not exists brand text;
create index if not exists idx_drinks_brand on drinks (brand);

alter table drinks_pending add column if not exists brand text;
