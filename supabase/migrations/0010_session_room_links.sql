-- 0010_session_room_links.sql
--
-- Foundation for the rooms × sessions experience (Step 1):
--   • messages gain a `kind` (user | arrival | departure | move) and an
--     optional `payload` jsonb so room chats can render system events
--     ("Marcus has lit up — Padrón 1964 · Old Fashioned") without a
--     separate table.
--   • rooms gain a `mode` (chat | voice) so the picker can render voice
--     rooms with a Patron lock without a parallel table.
--   • A partial index on sessions(room_id) WHERE ended_at IS NULL gives
--     us a fast "who's lit up in this room right now?" query for the
--     "Where are you sitting?" picker's live-now section.
--   • Two SECURITY DEFINER RPCs let the server post arrival/departure
--     system messages on behalf of the user — clients can't spoof them
--     because the messages_insert_member policy gates on `kind = 'user'`.

set search_path = public;

-- ─────────────────────────────────────────────────────────────────────
-- Rooms: mode (chat | voice). Defaults to chat so existing rows keep
-- working unchanged.
-- ─────────────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rooms'
      and column_name = 'mode'
  ) then
    alter table rooms add column mode text not null default 'chat'
      check (mode in ('chat', 'voice'));
  end if;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- Messages: kind + payload. Existing rows are 'user'. Body becomes
-- nullable for system messages whose content lives in the payload.
-- ─────────────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'messages'
      and column_name = 'kind'
  ) then
    alter table messages add column kind text not null default 'user'
      check (kind in ('user', 'arrival', 'departure', 'move'));
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'messages'
      and column_name = 'payload'
  ) then
    alter table messages add column payload jsonb;
  end if;
end;
$$;

-- The original body check requires length 1..2000. System messages
-- carry their content in payload, so relax the check to allow an empty
-- body when kind != 'user'. Drop and re-add to swap predicates safely.
alter table messages drop constraint if exists messages_body_check;
alter table messages add constraint messages_body_check
  check (
    (kind = 'user' and length(body) between 1 and 2000)
    or (kind <> 'user' and length(body) between 0 and 2000)
  );

-- Tighten the insert policy so clients can only post `kind = 'user'`.
-- The system-message RPCs below run as SECURITY DEFINER and bypass RLS
-- to write arrivals/departures/moves on the user's behalf.
drop policy if exists messages_insert_member on messages;
create policy messages_insert_member on messages
  for insert with check (
    kind = 'user'
    and sender_id = auth.uid()
    and (
      exists (select 1 from room_members m where m.room_id = messages.room_id and m.user_id = auth.uid())
      or exists (select 1 from rooms r where r.id = messages.room_id and r.owner_id = auth.uid())
    )
  );

-- ─────────────────────────────────────────────────────────────────────
-- Sessions: partial index for live-now queries. Without this,
-- "who's burning in this room right now?" scans every session ever
-- recorded for the room.
-- ─────────────────────────────────────────────────────────────────────
create index if not exists sessions_room_active_idx
  on sessions (room_id)
  where ended_at is null;

-- ─────────────────────────────────────────────────────────────────────
-- post_system_message — the SECURITY DEFINER helper that lets the
-- session lifecycle write 'arrival' / 'departure' / 'move' rows. We
-- gate on auth.uid() being the actor to keep clients honest.
-- ─────────────────────────────────────────────────────────────────────
create or replace function post_system_message(
  p_room_id uuid,
  p_kind text,
  p_payload jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_id uuid;
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  if p_kind not in ('arrival', 'departure', 'move') then
    raise exception 'invalid kind: %', p_kind;
  end if;

  -- The actor must be allowed to read messages in this room (same gate
  -- the SELECT policy applies). We mirror the policy here so the
  -- definer-rights call doesn't smuggle writes into rooms the user
  -- can't even see.
  if not exists (
    select 1 from rooms r
    where r.id = p_room_id and (
      r.is_private = false
      or r.owner_id = v_user
      or exists (select 1 from room_members m where m.room_id = r.id and m.user_id = v_user)
    )
  ) then
    raise exception 'not a member of room %', p_room_id;
  end if;

  insert into messages (room_id, sender_id, body, kind, payload)
  values (p_room_id, v_user, '', p_kind, p_payload)
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function post_system_message(uuid, text, jsonb) from public;
grant execute on function post_system_message(uuid, text, jsonb) to authenticated;
