-- 0001_init_schema.sql
-- Base schema for The Final Third (PRD v3) — extends original spec with:
--   - room_presence, voice_rooms, voice_participants
--   - drops, badges, user_badges, event_rsvps
--   - device_tokens, entitlements
--   - audit fields, soft delete on messages
--   - canonical reactions enum
--   - additional profile prefs and session fields

set search_path = public;
create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────────────────────────────────────
-- profiles
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text not null,
  handle text unique,
  avatar_url text,
  bio text,
  city text,
  is_honduras_local boolean not null default false,
  is_premium boolean not null default false,
  audio_theme text,                          -- last-used ambient theme
  voice_enabled boolean not null default false,
  ghost_mode_default boolean not null default false,
  notif_prefs jsonb not null default '{
    "the_usual": true,
    "arrival_signal": true,
    "drops": true,
    "events": true
  }'::jsonb,
  quiet_hours_start time,                    -- local time
  quiet_hours_end time,
  timezone text,                             -- IANA, e.g. America/Tegucigalpa
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- cigars
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists cigars (
  id uuid primary key default gen_random_uuid(),
  brand text not null,
  line text not null,
  vitola text,
  country text,
  wrapper text,
  binder text,
  filler text,
  ring_gauge int,
  length numeric,
  strength int check (strength between 1 and 5),
  flavor_notes text[] not null default '{}',
  origin_story text,
  affiliate_link text,
  image_url text,
  fun_fact text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_cigars_brand_line on cigars (brand, line) where is_archived = false;
create index if not exists idx_cigars_strength on cigars (strength) where is_archived = false;
create index if not exists idx_cigars_wrapper on cigars (wrapper) where is_archived = false;

create table if not exists cigars_pending (
  id uuid primary key default gen_random_uuid(),
  submitted_by uuid references profiles(id) on delete set null,
  brand text,
  line text,
  vitola text,
  country text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- drinks
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists drinks (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  subtype text,
  image_url text,
  created_at timestamptz not null default now()
);

create index if not exists idx_drinks_category on drinks (category);

-- ─────────────────────────────────────────────────────────────────────────────
-- rooms
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references profiles(id) on delete set null,
  name text not null,
  description text,
  theme text,
  is_private boolean not null default false,
  audio_theme text,
  created_at timestamptz not null default now()
);

create index if not exists idx_rooms_private on rooms (is_private);
create index if not exists idx_rooms_owner on rooms (owner_id);

create table if not exists room_members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'moderator', 'member')),
  joined_at timestamptz not null default now(),
  unique (room_id, user_id)
);

-- room_presence — durable presence state (ephemeral "in the room right now"
-- is broadcast via Supabase Presence channel; this row backs ghost-mode
-- persistence and arrival-signal triggers).
create table if not exists room_presence (
  room_id uuid not null references rooms(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  is_ghost boolean not null default false,
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- messages + reactions (canonical reaction codes)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  sender_id uuid references profiles(id) on delete set null,
  body text not null check (length(body) between 1 and 2000),
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_messages_room_created
  on messages (room_id, created_at desc);

create table if not exists message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references messages(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  reaction text not null
    check (reaction in ('toast', 'fire', 'smoke', 'salute', 'love')),
  created_at timestamptz not null default now(),
  unique (message_id, user_id, reaction)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- voice rooms (LiveKit shadow tables — token issuance reads these)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists voice_rooms (
  id uuid primary key default gen_random_uuid(),
  room_id uuid unique not null references rooms(id) on delete cascade,
  max_speakers int not null default 6 check (max_speakers between 1 and 12),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists voice_participants (
  id uuid primary key default gen_random_uuid(),
  voice_room_id uuid not null references voice_rooms(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'listener' check (role in ('speaker', 'listener')),
  is_muted boolean not null default true,
  joined_at timestamptz not null default now(),
  unique (voice_room_id, user_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- sessions
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  room_id uuid references rooms(id) on delete set null,
  cigar_id uuid references cigars(id) on delete set null,
  drink_id uuid references drinks(id) on delete set null,
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_minutes int,
  flavor_rating int check (flavor_rating between 1 and 5),
  draw_rating int check (draw_rating between 1 and 5),
  overall_rating int check (overall_rating between 1 and 5),
  would_smoke_again boolean,
  notes text,
  mood_score int check (mood_score between 1 and 10),
  unwind_success boolean,
  lighting_method text check (lighting_method in ('match', 'torch', 'cedar', 'soft_flame')),
  is_ghost boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_sessions_user_started
  on sessions (user_id, started_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- usuals
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists usuals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique not null references profiles(id) on delete cascade,
  preferred_time time,
  cigar_id uuid references cigars(id) on delete set null,
  drink_id uuid references drinks(id) on delete set null,
  enabled boolean not null default true,
  streak_count int not null default 0,
  last_completed_at timestamptz,
  updated_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- connections
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(id) on delete cascade,
  addressee_id uuid not null references profiles(id) on delete cascade,
  status text not null check (status in ('pending', 'accepted', 'declined', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> addressee_id)
);

create unique index if not exists uq_connections_pair
  on connections (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  );

create index if not exists idx_connections_users
  on connections (requester_id, addressee_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- events + RSVPs
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists events (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid references profiles(id) on delete set null,
  title text not null,
  location_name text,
  city text,
  datetime timestamptz,
  cigar_id uuid references cigars(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_events_city_time on events (city, datetime);

create table if not exists event_rsvps (
  event_id uuid not null references events(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  status text not null check (status in ('going', 'maybe', 'declined')),
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- drops (Cigar Drop System — featured cigar + limited-time room window)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists drops (
  id uuid primary key default gen_random_uuid(),
  cigar_id uuid not null references cigars(id) on delete cascade,
  room_id uuid references rooms(id) on delete set null,
  hero_copy text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists idx_drops_window on drops (starts_at, ends_at);

-- ─────────────────────────────────────────────────────────────────────────────
-- reputation badges
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists badges (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  description text not null,
  created_at timestamptz not null default now()
);

create table if not exists user_badges (
  user_id uuid not null references profiles(id) on delete cascade,
  badge_id uuid not null references badges(id) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- entitlements (RevenueCat mirror; client trusts RC; this is server-side cache)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  product_id text not null,
  is_active boolean not null default false,
  renews_at timestamptz,
  store text not null check (store in ('app_store', 'play_store', 'stripe', 'promo')),
  raw jsonb,
  updated_at timestamptz not null default now(),
  unique (user_id, product_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- device tokens (APNs)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios', 'android')),
  env text not null default 'production' check (env in ('production', 'sandbox')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- app_config (server-driven copy + flags)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- updated_at trigger
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  for t in
    select unnest(array[
      'profiles', 'usuals', 'connections',
      'entitlements', 'device_tokens', 'app_config'
    ])
  loop
    execute format(
      'drop trigger if exists trg_%1$s_updated_at on %1$s;
       create trigger trg_%1$s_updated_at before update on %1$s
       for each row execute function set_updated_at();',
      t
    );
  end loop;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- realtime publication (chat, presence, reactions, voice)
-- ─────────────────────────────────────────────────────────────────────────────
alter table messages replica identity full;
alter table message_reactions replica identity full;
alter table room_presence replica identity full;
alter table room_members replica identity full;
alter table voice_participants replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;
end;
$$;

alter publication supabase_realtime add table messages;
alter publication supabase_realtime add table message_reactions;
alter publication supabase_realtime add table room_presence;
alter publication supabase_realtime add table room_members;
alter publication supabase_realtime add table voice_participants;
