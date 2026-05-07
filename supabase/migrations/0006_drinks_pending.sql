-- 0006_drinks_pending.sql
-- Mirror of the live `drinks_pending` table created via MCP. Same shape
-- as cigars_pending: members submit suggestions, a moderator approves
-- (manually for now via the dashboard) and the entry lands in drinks.

set search_path = public;

create table if not exists drinks_pending (
  id uuid primary key default gen_random_uuid(),
  submitted_by uuid references profiles(id) on delete set null,
  name text,
  category text,
  subtype text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table drinks_pending enable row level security;

drop policy if exists drinks_pending_select_own on drinks_pending;
create policy drinks_pending_select_own on drinks_pending
  for select using (submitted_by = auth.uid());

drop policy if exists drinks_pending_insert_self on drinks_pending;
create policy drinks_pending_insert_self on drinks_pending
  for insert with check (submitted_by = auth.uid());
