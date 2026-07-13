-- GOAT phase 3A: additive, backward-compatible local migration.
-- This file is intentionally not pushed to the production project in this phase.

create extension if not exists pgcrypto;

create or replace function public.goat_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  gender text not null default '男',
  birth_year integer not null default 2000,
  birth_month integer not null default 1,
  birth_day integer not null default 1,
  height numeric not null default 175,
  current_weight numeric not null default 70,
  target_kcal numeric not null default 2000,
  target_p numeric not null default 150,
  target_c numeric not null default 200,
  target_f numeric not null default 60,
  training_data jsonb not null default '[]'::jsonb,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.food_dictionary (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  protein numeric not null default 0,
  carbs numeric not null default 0,
  fat numeric not null default 0,
  calories numeric not null default 0,
  category text not null default '其他',
  unit text not null default 'g',
  weight_per_unit numeric not null default 0,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.diet_logs (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  food_name text not null,
  p numeric not null default 0,
  c numeric not null default 0,
  f numeric not null default 0,
  kcal numeric not null default 0,
  meal_type text not null default '加餐',
  date date not null,
  amount numeric not null default 100,
  unit text not null default 'g',
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.exercise_logs (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null default '运动',
  kcal numeric not null default 0,
  start_time text,
  end_time text,
  date date not null,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.daily_tracking (
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  water_ml integer not null default 0,
  weight_kg numeric not null default 0,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, date)
);

create table if not exists public.water_intake_records (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  recorded_at timestamptz not null,
  amount_ml integer not null,
  is_legacy_aggregate boolean not null default false,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.body_weight_logs (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  weight_kg numeric(5, 2) not null,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, date)
);

create table if not exists public.training_sessions (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default '训练',
  date date not null,
  exercises jsonb not null default '[]'::jsonb,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sync_tombstones (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null,
  entity_id text not null,
  deleted_at timestamptz not null default now(),
  version integer not null default 1,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, entity_type, entity_id)
);

create table if not exists public.client_operations (
  operation_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null,
  entity_id text not null,
  action text not null,
  payload jsonb not null default '{}'::jsonb,
  response jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, operation_id)
);

create table if not exists public.ai_usage_daily (
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  request_count integer not null default 0,
  client_operation_ids jsonb not null default '[]'::jsonb,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, date)
);

-- Add the new columns to phase-one tables without renaming or removing old data.
do $$
declare
  table_name text;
begin
  foreach table_name in array array['user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs', 'daily_tracking'] loop
    execute format('alter table public.%I add column if not exists version integer not null default 1', table_name);
    execute format('alter table public.%I add column if not exists deleted_at timestamptz', table_name);
    execute format('alter table public.%I add column if not exists client_operation_id text', table_name);
    execute format('alter table public.%I add column if not exists created_at timestamptz not null default now()', table_name);
    execute format('alter table public.%I add column if not exists updated_at timestamptz not null default now()', table_name);
  end loop;
end;
$$;

create unique index if not exists food_dictionary_client_operation_idx
  on public.food_dictionary (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists diet_logs_client_operation_idx
  on public.diet_logs (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists exercise_logs_client_operation_idx
  on public.exercise_logs (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists water_intake_records_client_operation_idx
  on public.water_intake_records (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists body_weight_logs_client_operation_idx
  on public.body_weight_logs (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists training_sessions_client_operation_idx
  on public.training_sessions (user_id, client_operation_id)
  where client_operation_id is not null;

create index if not exists food_dictionary_updated_idx on public.food_dictionary (user_id, updated_at);
create index if not exists diet_logs_updated_idx on public.diet_logs (user_id, updated_at);
create index if not exists exercise_logs_updated_idx on public.exercise_logs (user_id, updated_at);
create index if not exists daily_tracking_updated_idx on public.daily_tracking (user_id, updated_at);
create index if not exists water_intake_records_updated_idx on public.water_intake_records (user_id, updated_at);
create index if not exists body_weight_logs_updated_idx on public.body_weight_logs (user_id, updated_at);
create index if not exists training_sessions_updated_idx on public.training_sessions (user_id, updated_at);
create index if not exists sync_tombstones_updated_idx on public.sync_tombstones (user_id, updated_at);

create or replace function public.goat_add_check_if_missing(
  table_name text,
  constraint_name text,
  expression text
)
returns void
language plpgsql
as $$
begin
  if not exists (
    select 1 from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    where n.nspname = 'public'
      and r.relname = table_name
      and c.conname = constraint_name
  ) then
    execute format(
      'alter table public.%I add constraint %I check (%s) not valid',
      table_name, constraint_name, expression
    );
  end if;
end;
$$;

select public.goat_add_check_if_missing('user_profiles', 'user_profiles_weight_range', 'current_weight >= 20 and current_weight <= 300');
select public.goat_add_check_if_missing('food_dictionary', 'food_dictionary_nutrition_nonnegative', 'protein >= 0 and carbs >= 0 and fat >= 0 and calories >= 0');
select public.goat_add_check_if_missing('diet_logs', 'diet_logs_nutrition_nonnegative', 'p >= 0 and c >= 0 and f >= 0 and kcal >= 0 and amount >= 0');
select public.goat_add_check_if_missing('diet_logs', 'diet_logs_meal_type_valid', 'meal_type in (''早餐'', ''午餐'', ''晚餐'', ''加餐'')');
select public.goat_add_check_if_missing('exercise_logs', 'exercise_logs_kcal_nonnegative', 'kcal >= 0');
select public.goat_add_check_if_missing('daily_tracking', 'daily_tracking_water_nonnegative', 'water_ml >= 0');
select public.goat_add_check_if_missing('daily_tracking', 'daily_tracking_weight_range', 'weight_kg = 0 or (weight_kg >= 20 and weight_kg <= 300)');
select public.goat_add_check_if_missing('water_intake_records', 'water_intake_amount_range', 'amount_ml > 0 and amount_ml <= 10000');
select public.goat_add_check_if_missing('body_weight_logs', 'body_weight_range', 'weight_kg >= 20 and weight_kg <= 300');
select public.goat_add_check_if_missing('ai_usage_daily', 'ai_usage_nonnegative', 'request_count >= 0');

create or replace function public.consume_ai_quota(
  p_user_id uuid,
  p_date date,
  p_limit integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'not_authorized';
  end if;

  insert into public.ai_usage_daily (user_id, date, request_count)
  values (p_user_id, p_date, 1)
  on conflict (user_id, date) do update
  set request_count = public.ai_usage_daily.request_count + 1
  where public.ai_usage_daily.request_count < p_limit;

  return found;
end;
$$;

revoke all on function public.consume_ai_quota(uuid, date, integer) from public;
grant execute on function public.consume_ai_quota(uuid, date, integer) to authenticated;

drop trigger if exists user_profiles_updated_at on public.user_profiles;
create trigger user_profiles_updated_at before update on public.user_profiles
for each row execute function public.goat_set_updated_at();

do $$
declare
  table_name text;
begin
  foreach table_name in array array['food_dictionary', 'diet_logs', 'exercise_logs', 'daily_tracking', 'water_intake_records', 'body_weight_logs', 'training_sessions', 'sync_tombstones', 'client_operations', 'ai_usage_daily'] loop
    execute format('drop trigger if exists %I on public.%I', table_name || '_updated_at', table_name);
    execute format('create trigger %I before update on public.%I for each row execute function public.goat_set_updated_at()', table_name || '_updated_at', table_name);
  end loop;
end;
$$;

-- Preserve old daily aggregates as stable detail records. Midnight is a
-- migration marker, not a fabricated drinking time.
insert into public.water_intake_records (
  id, user_id, date, recorded_at, amount_ml, is_legacy_aggregate
)
select
  'legacy_water_' || user_id::text || '_' || to_char(date::date, 'YYYY-MM-DD'),
  user_id,
  date::date,
  date::date::timestamptz,
  water_ml,
  true
from public.daily_tracking
where water_ml > 0
on conflict (id) do nothing;

insert into public.body_weight_logs (id, user_id, date, weight_kg)
select
  'legacy_weight_' || user_id::text || '_' || to_char(date::date, 'YYYY-MM-DD'),
  user_id,
  date::date,
  weight_kg
from public.daily_tracking
where weight_kg >= 20 and weight_kg <= 300
on conflict (user_id, date) do update
set weight_kg = excluded.weight_kg;

-- RLS is explicit for every user-owned table. No public or permanent-true policy.
do $$
declare
  table_name text;
begin
  foreach table_name in array array['food_dictionary', 'diet_logs', 'exercise_logs', 'daily_tracking', 'water_intake_records', 'body_weight_logs', 'training_sessions', 'sync_tombstones', 'client_operations', 'ai_usage_daily'] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('drop policy if exists goat_select_own on public.%I', table_name);
    execute format('drop policy if exists goat_insert_own on public.%I', table_name);
    execute format('drop policy if exists goat_update_own on public.%I', table_name);
    execute format('drop policy if exists goat_delete_own on public.%I', table_name);
    execute format('create policy goat_select_own on public.%I for select using (auth.uid() = user_id)', table_name);
    execute format('create policy goat_insert_own on public.%I for insert with check (auth.uid() = user_id)', table_name);
    execute format('create policy goat_update_own on public.%I for update using (auth.uid() = user_id) with check (auth.uid() = user_id)', table_name);
    execute format('create policy goat_delete_own on public.%I for delete using (auth.uid() = user_id)', table_name);
  end loop;
end;
$$;

-- Chat history is an existing client-referenced table. Protect it when it is
-- present, but do not create or reshape it in this additive migration.
do $$
begin
  if to_regclass('public.chat_history') is not null then
    alter table public.chat_history enable row level security;
    drop policy if exists goat_chat_select_own on public.chat_history;
    drop policy if exists goat_chat_insert_own on public.chat_history;
    drop policy if exists goat_chat_update_own on public.chat_history;
    drop policy if exists goat_chat_delete_own on public.chat_history;
    create policy goat_chat_select_own on public.chat_history
      for select using (auth.uid() = user_id);
    create policy goat_chat_insert_own on public.chat_history
      for insert with check (auth.uid() = user_id);
    create policy goat_chat_update_own on public.chat_history
      for update using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
    create policy goat_chat_delete_own on public.chat_history
      for delete using (auth.uid() = user_id);
  end if;
end;
$$;

alter table public.user_profiles enable row level security;
drop policy if exists goat_profile_select_own on public.user_profiles;
drop policy if exists goat_profile_insert_own on public.user_profiles;
drop policy if exists goat_profile_update_own on public.user_profiles;
drop policy if exists goat_profile_delete_own on public.user_profiles;
create policy goat_profile_select_own on public.user_profiles for select using (auth.uid() = id);
create policy goat_profile_insert_own on public.user_profiles for insert with check (auth.uid() = id);
create policy goat_profile_update_own on public.user_profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy goat_profile_delete_own on public.user_profiles for delete using (auth.uid() = id);

create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_user() from public;
grant execute on function public.delete_user() to authenticated;
