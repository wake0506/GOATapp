/*
Purpose: Add missing versioning, soft-delete, idempotency and timestamp fields
         to existing GOATapp tables.
Read-only: No.
Data modification: Adds columns only; existing rows are preserved.
Expected time: Under 30 seconds for normal table sizes.
Success: Each existing table keeps its old columns and gains only missing fields.
Failure/retry: Safe to rerun after reviewing the specific error.
*/

begin;

alter table if exists public.user_profiles
  add column if not exists version integer not null default 1,
  add column if not exists deleted_at timestamptz,
  add column if not exists client_operation_id text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.food_dictionary
  add column if not exists version integer not null default 1,
  add column if not exists deleted_at timestamptz,
  add column if not exists client_operation_id text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.diet_logs
  add column if not exists version integer not null default 1,
  add column if not exists deleted_at timestamptz,
  add column if not exists client_operation_id text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.exercise_logs
  add column if not exists version integer not null default 1,
  add column if not exists deleted_at timestamptz,
  add column if not exists client_operation_id text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.daily_tracking
  add column if not exists version integer not null default 1,
  add column if not exists deleted_at timestamptz,
  add column if not exists client_operation_id text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

commit;
