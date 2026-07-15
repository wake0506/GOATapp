-- GOAT phase 3C: additive server-side data services. Do not edit prior migrations.

create table if not exists public.sync_diagnostics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (char_length(trim(device_id)) between 8 and 128),
  app_version text not null check (char_length(trim(app_version)) between 1 and 64),
  sync_enabled boolean not null,
  pending_operations integer not null default 0 check (pending_operations >= 0),
  last_success_at timestamptz,
  last_error_code text check (last_error_code is null or last_error_code ~ '^[A-Z0-9_]{1,64}$'),
  last_error_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (user_id, device_id)
);

create table if not exists public.app_feature_flags (
  key text primary key check (key ~ '^[a-z][a-z0-9_]{1,63}$'),
  enabled boolean not null default false,
  config jsonb not null default '{}'::jsonb check (jsonb_typeof(config) = 'object'),
  minimum_app_version text,
  updated_at timestamptz not null default now()
);

drop trigger if exists sync_diagnostics_updated_at on public.sync_diagnostics;
create trigger sync_diagnostics_updated_at before update on public.sync_diagnostics
for each row execute function public.goat_set_updated_at();
drop trigger if exists app_feature_flags_updated_at on public.app_feature_flags;
create trigger app_feature_flags_updated_at before update on public.app_feature_flags
for each row execute function public.goat_set_updated_at();

insert into public.app_feature_flags (key, enabled, config) values
  ('versioned_sync', false, '{}'::jsonb),
  ('nutrition_ai', true, '{}'::jsonb),
  ('training_ai_insights', false, '{}'::jsonb),
  ('voice_entry', true, '{}'::jsonb)
on conflict (key) do nothing;

alter table public.sync_diagnostics enable row level security;
alter table public.app_feature_flags enable row level security;
drop policy if exists goat_sync_diagnostics_select_own on public.sync_diagnostics;
drop policy if exists goat_sync_diagnostics_insert_own on public.sync_diagnostics;
drop policy if exists goat_sync_diagnostics_update_own on public.sync_diagnostics;
drop policy if exists goat_sync_diagnostics_delete_own on public.sync_diagnostics;
create policy goat_sync_diagnostics_select_own on public.sync_diagnostics for select to authenticated using (auth.uid() = user_id);
create policy goat_sync_diagnostics_insert_own on public.sync_diagnostics for insert to authenticated with check (auth.uid() = user_id);
create policy goat_sync_diagnostics_update_own on public.sync_diagnostics for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy goat_sync_diagnostics_delete_own on public.sync_diagnostics for delete to authenticated using (auth.uid() = user_id);
drop policy if exists goat_feature_flags_authenticated_read on public.app_feature_flags;
create policy goat_feature_flags_authenticated_read on public.app_feature_flags for select to authenticated using (auth.uid() is not null);
revoke all on table public.sync_diagnostics, public.app_feature_flags from anon;
grant select, insert, update, delete on table public.sync_diagnostics to authenticated;
grant select on table public.app_feature_flags to authenticated;
revoke insert, update, delete on table public.app_feature_flags from authenticated;

create or replace function public.get_daily_summary(p_date date)
returns table (
  date date,
  calories_in numeric,
  calories_burned numeric,
  net_calories numeric,
  protein_g numeric,
  carbs_g numeric,
  fat_g numeric,
  water_ml bigint,
  weight_kg numeric,
  exercise_count bigint,
  training_count bigint,
  training_volume_kg numeric,
  completed_sets bigint
)
language sql
security invoker
set search_path = public
stable
as $$
  with current_user as (select auth.uid() as id),
  diet as (
    select coalesce(sum(d.kcal), 0) as calories_in,
           coalesce(sum(d.p), 0) as protein_g,
           coalesce(sum(d.c), 0) as carbs_g,
           coalesce(sum(d.f), 0) as fat_g
    from public.diet_logs d join current_user u on d.user_id = u.id
    where d.date = p_date and d.deleted_at is null
  ), exercise as (
    select coalesce(sum(e.kcal), 0) as calories_burned, count(*) as exercise_count
    from public.exercise_logs e join current_user u on e.user_id = u.id
    where e.date = p_date and e.deleted_at is null
  ), water as (
    select coalesce(sum(w.amount_ml), 0)::bigint as water_ml
    from public.water_intake_records w join current_user u on w.user_id = u.id
    where w.date = p_date and w.deleted_at is null
  ), weight as (
    select coalesce(max(b.weight_kg), 0) as weight_kg
    from public.body_weight_logs b join current_user u on b.user_id = u.id
    where b.date = p_date and b.deleted_at is null
  ), training as (
    select count(*)::bigint as training_count,
           coalesce(sum(x.volume), 0) as training_volume_kg,
           coalesce(sum(x.completed_sets), 0)::bigint as completed_sets
    from public.training_sessions t
    join current_user u on t.user_id = u.id
    cross join lateral (
      select coalesce(sum(coalesce((s.value->>'weight')::numeric, 0) * coalesce((s.value->>'reps')::numeric, 0)), 0) as volume,
             count(s.value) filter (where coalesce((s.value->>'reps')::integer, 0) > 0) as completed_sets
      from jsonb_array_elements(coalesce(t.exercises, '[]'::jsonb)) e(value)
      cross join lateral jsonb_array_elements(coalesce(e.value->'sets', '[]'::jsonb)) s(value)
    ) x
    where t.date = p_date and t.deleted_at is null
  )
  select p_date, diet.calories_in, exercise.calories_burned,
         diet.calories_in - exercise.calories_burned,
         diet.protein_g, diet.carbs_g, diet.fat_g, water.water_ml, weight.weight_kg,
         exercise.exercise_count, training.training_count, training.training_volume_kg, training.completed_sets
  from diet cross join exercise cross join water cross join weight cross join training;
$$;

create or replace function public.get_weekly_summary(p_start_date date)
returns table (
  start_date date,
  end_date date,
  days jsonb,
  average_calories_in numeric,
  average_calories_burned numeric,
  average_water_ml numeric,
  average_training_volume_kg numeric,
  training_count bigint,
  weight_start_kg numeric,
  weight_end_kg numeric,
  weight_change_kg numeric,
  average_macro_goal_completion_pct numeric
)
language sql
security invoker
set search_path = public
stable
as $$
  with current_user as (select auth.uid() as id),
  day_rows as (
    select * from generate_series(p_start_date, p_start_date + 6, interval '1 day') d(day)
  ), daily as (
    select s.* from day_rows r cross join lateral public.get_daily_summary(r.day::date) s
  ), profile as (
    select target_p, target_c, target_f from public.user_profiles p join current_user u on p.id = u.id
  ), macros as (
    select avg(case when profile.target_p > 0 then d.protein_g / profile.target_p else null end) +
           avg(case when profile.target_c > 0 then d.carbs_g / profile.target_c else null end) +
           avg(case when profile.target_f > 0 then d.fat_g / profile.target_f else null end) as three_macro_average
    from daily d cross join profile
  ), weights as (
    select weight_kg, date from daily where weight_kg > 0 order by date
  )
  select p_start_date, p_start_date + 6,
         jsonb_agg(jsonb_build_object('date', date, 'calories_in', calories_in,
           'calories_burned', calories_burned, 'water_ml', water_ml,
           'weight_kg', nullif(weight_kg, 0), 'training_volume_kg', training_volume_kg) order by date),
         avg(calories_in), avg(calories_burned), avg(water_ml), avg(training_volume_kg), sum(training_count),
         (select weight_kg from weights limit 1),
         (select weight_kg from weights offset greatest((select count(*) from weights) - 1, 0) limit 1),
         (select (select weight_kg from weights offset greatest((select count(*) from weights) - 1, 0) limit 1) - (select weight_kg from weights limit 1)),
         coalesce((select three_macro_average from macros) * 100 / 3, 0)
  from daily;
$$;

create or replace function public.assert_account_deletion_ready()
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  table_name text;
  column_name text;
begin
  foreach table_name in array array['user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs', 'daily_tracking', 'water_intake_records', 'body_weight_logs', 'training_sessions', 'sync_tombstones', 'client_operations', 'ai_usage_daily', 'sync_diagnostics'] loop
    column_name := case when table_name = 'user_profiles' then 'id' else 'user_id' end;
    if not exists (
      select 1 from pg_constraint c join pg_class r on r.oid = c.conrelid
      join pg_namespace n on n.oid = r.relnamespace
      join pg_attribute a on a.attrelid = r.oid and a.attnum = any(c.conkey)
      where c.contype = 'f' and c.confrelid = 'auth.users'::regclass and c.confdeltype = 'c'
        and n.nspname = 'public' and r.relname = table_name and a.attname = column_name
    ) then
      raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:%', table_name using errcode = 'check_violation';
    end if;
  end loop;
  if to_regclass('public.chat_history') is not null and not exists (
    select 1 from pg_constraint c join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    join pg_attribute a on a.attrelid = r.oid and a.attnum = any(c.conkey)
    where c.contype = 'f' and c.confrelid = 'auth.users'::regclass and c.confdeltype = 'c'
      and n.nspname = 'public' and r.relname = 'chat_history' and a.attname = 'user_id'
  ) then
    raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:chat_history' using errcode = 'check_violation';
  end if;
  return true;
end;
$$;

revoke all on function public.assert_account_deletion_ready() from public, anon, authenticated;
grant execute on function public.assert_account_deletion_ready() to service_role;
revoke all on function public.delete_user() from public, anon, authenticated;
revoke all on function public.get_daily_summary(date), public.get_weekly_summary(date) from public, anon;
grant execute on function public.get_daily_summary(date), public.get_weekly_summary(date) to authenticated;
