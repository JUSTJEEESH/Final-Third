-- 0002_rls_policies.sql
-- Row Level Security for The Final Third.

set search_path = public;

alter table profiles enable row level security;
alter table cigars enable row level security;
alter table cigars_pending enable row level security;
alter table drinks enable row level security;
alter table rooms enable row level security;
alter table room_members enable row level security;
alter table room_presence enable row level security;
alter table messages enable row level security;
alter table message_reactions enable row level security;
alter table voice_rooms enable row level security;
alter table voice_participants enable row level security;
alter table sessions enable row level security;
alter table usuals enable row level security;
alter table connections enable row level security;
alter table events enable row level security;
alter table event_rsvps enable row level security;
alter table drops enable row level security;
alter table badges enable row level security;
alter table user_badges enable row level security;
alter table entitlements enable row level security;
alter table device_tokens enable row level security;
alter table app_config enable row level security;

-- ─────────────────────────────────────────────────────────────────────────────
-- profiles: anyone can read; users can update their own row
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists profiles_select_all on profiles;
create policy profiles_select_all on profiles
  for select using (true);

drop policy if exists profiles_update_own on profiles;
create policy profiles_update_own on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists profiles_insert_own on profiles;
create policy profiles_insert_own on profiles
  for insert with check (id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- cigars / drinks: public read; writes only via service role or pending queue
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists cigars_select_all on cigars;
create policy cigars_select_all on cigars for select using (is_archived = false);

drop policy if exists drinks_select_all on drinks;
create policy drinks_select_all on drinks for select using (true);

-- cigars_pending: users see their own + can submit
drop policy if exists cigars_pending_select_own on cigars_pending;
create policy cigars_pending_select_own on cigars_pending
  for select using (submitted_by = auth.uid());

drop policy if exists cigars_pending_insert_self on cigars_pending;
create policy cigars_pending_insert_self on cigars_pending
  for insert with check (submitted_by = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- rooms: public rooms are visible to anyone; private only to members
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists rooms_select_visible on rooms;
create policy rooms_select_visible on rooms
  for select using (
    is_private = false
    or owner_id = auth.uid()
    or exists (
      select 1 from room_members m
      where m.room_id = rooms.id and m.user_id = auth.uid()
    )
  );

drop policy if exists rooms_insert_owner on rooms;
create policy rooms_insert_owner on rooms
  for insert with check (owner_id = auth.uid());

drop policy if exists rooms_update_owner on rooms;
create policy rooms_update_owner on rooms
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- room_members: visible if requester is member; insert self only
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists room_members_select on room_members;
create policy room_members_select on room_members
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from room_members m2
      where m2.room_id = room_members.room_id and m2.user_id = auth.uid()
    )
  );

drop policy if exists room_members_insert_self on room_members;
create policy room_members_insert_self on room_members
  for insert with check (
    user_id = auth.uid()
    and (
      not exists (select 1 from rooms r where r.id = room_id and r.is_private = true)
      or exists (select 1 from rooms r where r.id = room_id and r.owner_id = auth.uid())
    )
  );

drop policy if exists room_members_delete_self on room_members;
create policy room_members_delete_self on room_members
  for delete using (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- room_presence
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists room_presence_select on room_presence;
create policy room_presence_select on room_presence
  for select using (
    is_ghost = false
    or user_id = auth.uid()
    or exists (
      select 1 from rooms r
      where r.id = room_presence.room_id and r.owner_id = auth.uid()
    )
  );

drop policy if exists room_presence_upsert_self on room_presence;
create policy room_presence_upsert_self on room_presence
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- messages: read if room visible; insert requires membership
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists messages_select on messages;
create policy messages_select on messages
  for select using (
    deleted_at is null
    and exists (
      select 1 from rooms r where r.id = messages.room_id
        and (r.is_private = false
          or r.owner_id = auth.uid()
          or exists (select 1 from room_members m where m.room_id = r.id and m.user_id = auth.uid()))
    )
  );

drop policy if exists messages_insert_member on messages;
create policy messages_insert_member on messages
  for insert with check (
    sender_id = auth.uid()
    and (
      exists (select 1 from room_members m where m.room_id = messages.room_id and m.user_id = auth.uid())
      or exists (select 1 from rooms r where r.id = messages.room_id and r.owner_id = auth.uid())
    )
  );

drop policy if exists messages_update_own on messages;
create policy messages_update_own on messages
  for update using (sender_id = auth.uid()) with check (sender_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- reactions: react if you can read the message
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists reactions_select on message_reactions;
create policy reactions_select on message_reactions for select using (true);

drop policy if exists reactions_insert_self on message_reactions;
create policy reactions_insert_self on message_reactions
  for insert with check (user_id = auth.uid());

drop policy if exists reactions_delete_self on message_reactions;
create policy reactions_delete_self on message_reactions
  for delete using (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- voice rooms: same visibility as rooms; participants self-managed
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists voice_rooms_select on voice_rooms;
create policy voice_rooms_select on voice_rooms for select using (
  exists (
    select 1 from rooms r where r.id = voice_rooms.room_id
      and (r.is_private = false or r.owner_id = auth.uid()
        or exists (select 1 from room_members m where m.room_id = r.id and m.user_id = auth.uid()))
  )
);

drop policy if exists voice_participants_select on voice_participants;
create policy voice_participants_select on voice_participants for select using (true);

drop policy if exists voice_participants_upsert_self on voice_participants;
create policy voice_participants_upsert_self on voice_participants
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- sessions: only owner reads/writes
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists sessions_owner on sessions;
create policy sessions_owner on sessions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- usuals: only owner
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists usuals_owner on usuals;
create policy usuals_owner on usuals
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- connections: visible to either party; insert self as requester
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists connections_select on connections;
create policy connections_select on connections for select using (
  requester_id = auth.uid() or addressee_id = auth.uid()
);

drop policy if exists connections_insert on connections;
create policy connections_insert on connections for insert with check (
  requester_id = auth.uid()
);

drop policy if exists connections_update on connections;
create policy connections_update on connections for update using (
  requester_id = auth.uid() or addressee_id = auth.uid()
) with check (
  requester_id = auth.uid() or addressee_id = auth.uid()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- events / rsvps
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists events_select_all on events;
create policy events_select_all on events for select using (true);

drop policy if exists events_insert_self on events;
create policy events_insert_self on events for insert with check (creator_id = auth.uid());

drop policy if exists events_update_own on events;
create policy events_update_own on events for update using (creator_id = auth.uid())
  with check (creator_id = auth.uid());

drop policy if exists rsvps_select on event_rsvps;
create policy rsvps_select on event_rsvps for select using (true);

drop policy if exists rsvps_upsert_self on event_rsvps;
create policy rsvps_upsert_self on event_rsvps for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- drops: public read
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists drops_select_all on drops;
create policy drops_select_all on drops for select using (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- badges + user_badges: public read
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists badges_select_all on badges;
create policy badges_select_all on badges for select using (true);

drop policy if exists user_badges_select_all on user_badges;
create policy user_badges_select_all on user_badges for select using (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- entitlements + device_tokens: only owner
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists entitlements_owner on entitlements;
create policy entitlements_owner on entitlements
  for select using (user_id = auth.uid());

drop policy if exists device_tokens_owner on device_tokens;
create policy device_tokens_owner on device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- app_config: public read
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists app_config_select_all on app_config;
create policy app_config_select_all on app_config for select using (true);
