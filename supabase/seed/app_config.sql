insert into app_config (key, value) values
  ('greeting.evening',  '"Welcome back. Your chair is ready."'::jsonb),
  ('greeting.late',     '"The fire is still going."'::jsonb),
  ('greeting.morning',  '"Take it slow."'::jsonb),
  ('lighting.methods',  '["match","torch","cedar","soft_flame"]'::jsonb),
  ('audio.themes',      '["lounge_murmur","jazz","lofi","rain","fireplace"]'::jsonb),
  ('reactions.allowed', '["toast","fire","smoke","salute","love"]'::jsonb),
  ('paywall.copy',      '"Members keep their journal forever, host private rooms, and unlock pairings."'::jsonb)
on conflict (key) do update set value = excluded.value, updated_at = now();
