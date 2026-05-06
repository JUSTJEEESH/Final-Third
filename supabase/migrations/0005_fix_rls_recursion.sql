-- 0005_fix_rls_recursion.sql
-- Postgres rejected the original room_members_select policy with
-- "infinite recursion detected in policy for relation 'room_members'":
-- the policy's EXISTS subquery read room_members, which triggered the
-- same policy, which read room_members, ad infinitum. The fix is a
-- SECURITY DEFINER helper that bypasses RLS for the membership lookup,
-- breaking the cycle. Used from any policy that needs "is the caller a
-- member of this room?" so room visibility, message visibility, voice
-- room visibility, and message inserts all share one source of truth.

set search_path = public;

create or replace function public.is_room_member(rid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists(
    select 1 from room_members
    where room_id = rid and user_id = auth.uid()
  );
$$;

revoke all on function public.is_room_member(uuid) from public;
grant execute on function public.is_room_member(uuid) to authenticated, anon;

drop policy if exists room_members_select on room_members;
create policy room_members_select on room_members
  for select using (
    user_id = auth.uid()
    or public.is_room_member(room_id)
  );

drop policy if exists rooms_select_visible on rooms;
create policy rooms_select_visible on rooms
  for select using (
    is_private = false
    or owner_id = auth.uid()
    or public.is_room_member(id)
  );

drop policy if exists messages_select on messages;
create policy messages_select on messages
  for select using (
    deleted_at is null
    and exists (
      select 1 from rooms r where r.id = messages.room_id
        and (
          r.is_private = false
          or r.owner_id = auth.uid()
          or public.is_room_member(r.id)
        )
    )
  );

drop policy if exists messages_insert_member on messages;
create policy messages_insert_member on messages
  for insert with check (
    sender_id = auth.uid()
    and (
      public.is_room_member(room_id)
      or exists (select 1 from rooms r where r.id = messages.room_id and r.owner_id = auth.uid())
    )
  );

drop policy if exists voice_rooms_select on voice_rooms;
create policy voice_rooms_select on voice_rooms
  for select using (
    exists (select 1 from rooms r where r.id = voice_rooms.room_id
      and (r.is_private = false
           or r.owner_id = auth.uid()
           or public.is_room_member(r.id)))
  );
