-- 0003_views_and_helpers.sql
-- Materialized view: connection_chemistry — used by Social tab.

set search_path = public;

create or replace view connection_chemistry as
with paired as (
  select
    least(a.user_id, b.user_id) as user_a,
    greatest(a.user_id, b.user_id) as user_b,
    a.room_id,
    a.started_at,
    a.ended_at
  from sessions a
  join sessions b
    on a.room_id = b.room_id
   and a.user_id <> b.user_id
   and a.started_at < b.ended_at
   and b.started_at < a.ended_at
  where a.room_id is not null
    and a.ended_at is not null
    and b.ended_at is not null
)
select
  user_a,
  user_b,
  count(*) as sessions_together,
  sum(
    extract(
      epoch from (least(ended_at, lead(ended_at) over ()) -
                  greatest(started_at, lag(started_at) over ()))
    )
  )::int / 60 as minutes_together,
  max(ended_at) as last_session_at
from paired
group by user_a, user_b;

-- Streak helper: increments user's streak if they completed a session
-- within 36 hours of last_completed_at; otherwise resets to 1.
create or replace function update_streak_on_session_end()
returns trigger
language plpgsql
as $$
declare
  cutoff interval := interval '36 hours';
begin
  if new.ended_at is null then
    return new;
  end if;

  insert into usuals (user_id, last_completed_at, streak_count)
  values (new.user_id, new.ended_at, 1)
  on conflict (user_id) do update set
    streak_count = case
      when usuals.last_completed_at is null then 1
      when new.ended_at - usuals.last_completed_at <= cutoff then usuals.streak_count + 1
      else 1
    end,
    last_completed_at = new.ended_at,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists trg_sessions_update_streak on sessions;
create trigger trg_sessions_update_streak
  after insert or update of ended_at on sessions
  for each row
  when (new.ended_at is not null)
  execute function update_streak_on_session_end();
