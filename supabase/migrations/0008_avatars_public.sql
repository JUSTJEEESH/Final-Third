-- 0008_avatars_public.sql
-- Promote the avatars bucket to public so AsyncImage can fetch avatar
-- URLs directly without auth headers / signed URLs. Writes are still
-- locked down to the owning user via the folder-prefix-by-uid policies
-- from migration 0004.

set search_path = public;

update storage.buckets set public = true where id = 'avatars';

drop policy if exists avatars_select on storage.objects;
create policy avatars_select on storage.objects
  for select using (bucket_id = 'avatars');
