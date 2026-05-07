-- 0009_profiles_country.sql
-- Make the location story worldwide: a country column + a generic
-- is_local flag (was is_honduras_local). The onboarding flow now
-- captures both, with the local toggle's copy contextualized to the
-- user's chosen country.

set search_path = public;

alter table profiles add column if not exists country text;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'is_honduras_local'
  ) then
    alter table profiles rename column is_honduras_local to is_local;
  end if;
end;
$$;
