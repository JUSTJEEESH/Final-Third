-- 0011_room_live_now.sql
--
-- The doorway sheet's "lit up right now" section needs a per-room
-- aggregate (count + a sample of smokers with their cigars). Doing
-- this client-side would mean a fan-out fetch + RLS on `sessions`
-- doesn't expose other people's session rows by design.
--
-- This RPC runs as SECURITY DEFINER and returns only what's safe to
-- show in the picker: the count of active (non-ghost) sessions per
-- room, plus up to three smokers' display name / avatar / cigar
-- identity / minutes-in. Ghost sessions are filtered out — privacy
-- is a free-tier guarantee.

set search_path = public;

create or replace function room_live_now(p_room_ids uuid[])
returns table (
  room_id uuid,
  live_count int,
  smokers jsonb
)
language sql
security definer
set search_path = public
stable
as $$
  with active as (
    select
      s.room_id,
      s.user_id,
      s.started_at,
      greatest(0, floor(extract(epoch from (now() - s.started_at)) / 60))::int as minutes_in,
      p.display_name,
      p.avatar_url,
      c.brand as cigar_brand,
      c.line  as cigar_line
    from sessions s
    join profiles p on p.id = s.user_id
    left join cigars c on c.id = s.cigar_id
    where s.ended_at is null
      and s.is_ghost = false
      and s.room_id = any(p_room_ids)
  ),
  ranked as (
    select
      a.*,
      row_number() over (partition by a.room_id order by a.started_at desc) as rn
    from active a
  ),
  sample as (
    select
      r.room_id,
      jsonb_agg(
        jsonb_build_object(
          'user_id',      r.user_id,
          'display_name', r.display_name,
          'avatar_url',   r.avatar_url,
          'cigar_brand',  r.cigar_brand,
          'cigar_line',   r.cigar_line,
          'minutes_in',   r.minutes_in,
          'started_at',   r.started_at
        )
        order by r.started_at desc
      ) as smokers
    from ranked r
    where r.rn <= 3
    group by r.room_id
  ),
  totals as (
    select room_id, count(*)::int as live_count
    from active
    group by room_id
  )
  select
    t.room_id,
    t.live_count,
    coalesce(s.smokers, '[]'::jsonb) as smokers
  from totals t
  left join sample s on s.room_id = t.room_id;
$$;

revoke all on function room_live_now(uuid[]) from public;
grant execute on function room_live_now(uuid[]) to authenticated;
