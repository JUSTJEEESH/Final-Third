-- 0004_storage_buckets.sql
-- Storage bucket setup. avatars are private (signed-url reads), cigars
-- and drinks are public read.
--
-- Buckets are created via Supabase dashboard or `supabase storage` CLI;
-- this migration enforces the policy layer.

set search_path = public;

-- Ensure the buckets exist (idempotent inserts; storage.buckets is the
-- system table managed by Supabase Storage).
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', false),
  ('cigars',  'cigars',  true),
  ('drinks',  'drinks',  true)
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────
-- avatars: private. Users can read only their own object via signed URL,
-- but anyone can read via the API as long as they're authenticated.
-- ─────────────────────────────────────────────────────────────────────────
drop policy if exists avatars_select on storage.objects;
create policy avatars_select on storage.objects
  for select using (
    bucket_id = 'avatars'
    and auth.role() = 'authenticated'
  );

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects
  for update using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ─────────────────────────────────────────────────────────────────────────
-- cigars / drinks: public read; writes only via service role.
-- ─────────────────────────────────────────────────────────────────────────
drop policy if exists cigars_drinks_select on storage.objects;
create policy cigars_drinks_select on storage.objects
  for select using (bucket_id in ('cigars', 'drinks'));
