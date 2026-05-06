# The Final Third — Supabase Backend Schema & Architecture

## Database Overview

Supabase is the source of truth for:
- Authentication
- Profiles
- Cigar library
- Drinks
- Rooms
- Chat
- Presence
- Sessions
- Connections
- Events
- Premium state
- App config

---

# Tables

---

## profiles

```sql
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text not null,
  handle text unique,
  avatar_url text,
  bio text,
  city text,
  is_honduras_local boolean default false,
  is_premium boolean default false,
  created_at timestamptz default now()
);
```

---

## cigars

```sql
create table cigars (
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
  flavor_notes text[],
  origin_story text,
  affiliate_link text,
  image_url text,
  fun_fact text,
  created_at timestamptz default now()
);
```

---

## cigars_pending

```sql
create table cigars_pending (
  id uuid primary key default gen_random_uuid(),
  submitted_by uuid references profiles(id),
  brand text,
  line text,
  vitola text,
  country text,
  created_at timestamptz default now()
);
```

---

## drinks

```sql
create table drinks (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  subtype text,
  image_url text,
  created_at timestamptz default now()
);
```

---

## rooms

```sql
create table rooms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references profiles(id),
  name text not null,
  description text,
  theme text,
  is_private boolean default false,
  audio_theme text,
  created_at timestamptz default now()
);
```

---

## room_members

```sql
create table room_members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade
);
```

---

## messages

```sql
create table messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms(id) on delete cascade,
  sender_id uuid references profiles(id),
  body text not null,
  created_at timestamptz default now()
);
```

---

## message_reactions

```sql
create table message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid references messages(id) on delete cascade,
  user_id uuid references profiles(id),
  reaction text not null
);
```

---

## sessions

```sql
create table sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id),
  room_id uuid references rooms(id),
  cigar_id uuid references cigars(id),
  drink_id uuid references drinks(id),
  started_at timestamptz,
  ended_at timestamptz,
  duration_minutes int,
  flavor_rating int,
  draw_rating int,
  overall_rating int,
  would_smoke_again boolean,
  notes text,
  mood_score int,
  unwind_success boolean,
  created_at timestamptz default now()
);
```

---

## usuals

```sql
create table usuals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references profiles(id),
  preferred_time time,
  cigar_id uuid references cigars(id),
  drink_id uuid references drinks(id),
  enabled boolean default true,
  streak_count int default 0,
  last_completed_at timestamptz
);
```

---

## connections

```sql
create table connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid references profiles(id),
  addressee_id uuid references profiles(id),
  status text check (status in ('pending','accepted','declined')),
  created_at timestamptz default now()
);
```

---

## events

```sql
create table events (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid references profiles(id),
  title text not null,
  location_name text,
  city text,
  datetime timestamptz,
  cigar_id uuid references cigars(id),
  created_at timestamptz default now()
);
```

---

## app_config

```sql
create table app_config (
  key text primary key,
  value text not null
);
```

---

# Recommended Indexes

```sql
create index idx_messages_room_created
on messages(room_id, created_at desc);

create index idx_sessions_user_created
on sessions(user_id, created_at desc);

create index idx_connections_users
on connections(requester_id, addressee_id);

create index idx_rooms_private
on rooms(is_private);
```

---

# Realtime Channels

Use Supabase Realtime for:

- room presence
- messages
- reactions
- session presence state

Channel naming:
- room:{room_id}

---

# Storage Buckets

Buckets:
- avatars
- cigars
- drinks

Public:
- cigars
- drinks

Private:
- avatars

---

# Row Level Security

Enable RLS on all tables.

Rules:
- users can only modify own profile
- own sessions only editable by owner
- private room membership enforced
- message insert requires membership

---

# Edge Functions (Future)

Recommended:
- AI Sommelier recommendations
- Weekly recap generation
- Streak maintenance
- Notification scheduling