/*
Purpose: Ensure the complete additive GOATapp data schema exists.
Read-only: No.
Data modification: Creates only missing tables; never replaces existing tables.
Expected time: Under 30 seconds.
Success: All 11 target tables exist and legacy tables remain untouched.
Failure/retry: Safe to rerun. Do not manually create duplicate tables in Table Editor.
*/

begin;

create extension if not exists pgcrypto;

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
  training_data text not null default '',
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
  recorded_at timestamptz,
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
  claimed_at timestamptz,
  claim_token uuid,
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

-- Existing client_operations tables receive only the missing lease field.
alter table public.client_operations
  add column if not exists claimed_at timestamptz;
alter table public.client_operations
  add column if not exists claim_token uuid;

commit;
