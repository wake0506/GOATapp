-- TEST PROJECT ONLY.
-- Refuses to run unless the caller sets:
--   SET goat.contract_test_rollback = 'on';
-- This script removes only objects introduced by
-- 20260725000000_backend_contract_alignment.sql.

begin;

do $rollback_guard$
begin
  if pg_catalog.current_setting('goat.contract_test_rollback', true) is distinct from 'on' then
    raise exception 'TEST_ROLLBACK_GUARD_NOT_ENABLED';
  end if;
end;
$rollback_guard$;

alter table if exists public.training_sessions
  drop constraint if exists training_sessions_exercises_array;

drop table if exists public.ai_suggestion_feedback;
drop table if exists public.ai_suggestions;
drop table if exists public.ai_memories;
drop table if exists public.training_templates;

drop function if exists public.goat_protect_user_provided_memory();

-- Restore the prior account-deletion readiness contract.
create or replace function public.assert_account_deletion_ready()
returns boolean
language plpgsql
security definer
set search_path = ''
as $deletion_ready$
declare
  expected_table text;
  expected_column text;
begin
  foreach expected_table in array array[
    'user_profiles',
    'food_dictionary',
    'diet_logs',
    'exercise_logs',
    'daily_tracking',
    'water_intake_records',
    'body_weight_logs',
    'training_sessions',
    'sync_tombstones',
    'client_operations',
    'ai_usage_daily',
    'sync_diagnostics'
  ] loop
    expected_column := case
      when expected_table = 'user_profiles' then 'id'
      else 'user_id'
    end;

    if pg_catalog.to_regclass(pg_catalog.format('public.%I', expected_table)) is null then
      raise exception 'ACCOUNT_DELETION_TABLE_MISSING:%', expected_table
        using errcode = 'check_violation';
    end if;

    if not exists (
      select 1
      from pg_catalog.pg_constraint constraint_row
      join pg_catalog.pg_class source_table
        on source_table.oid = constraint_row.conrelid
      join pg_catalog.pg_namespace source_schema
        on source_schema.oid = source_table.relnamespace
      join pg_catalog.pg_attribute source_column
        on source_column.attrelid = source_table.oid
       and source_column.attnum = any(constraint_row.conkey)
      where constraint_row.contype = 'f'
        and constraint_row.confrelid = pg_catalog.to_regclass('auth.users')
        and constraint_row.confdeltype = 'c'
        and source_schema.nspname = 'public'
        and source_table.relname = expected_table
        and source_column.attname = expected_column
    ) then
      raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:%', expected_table
        using errcode = 'check_violation';
    end if;
  end loop;

  if pg_catalog.to_regclass('public.chat_history') is not null
     and not exists (
       select 1
       from pg_catalog.pg_constraint constraint_row
       join pg_catalog.pg_class source_table
         on source_table.oid = constraint_row.conrelid
       join pg_catalog.pg_namespace source_schema
         on source_schema.oid = source_table.relnamespace
       join pg_catalog.pg_attribute source_column
         on source_column.attrelid = source_table.oid
        and source_column.attnum = any(constraint_row.conkey)
       where constraint_row.contype = 'f'
         and constraint_row.confrelid = pg_catalog.to_regclass('auth.users')
         and constraint_row.confdeltype = 'c'
         and source_schema.nspname = 'public'
         and source_table.relname = 'chat_history'
         and source_column.attname = 'user_id'
     ) then
    raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:chat_history'
      using errcode = 'check_violation';
  end if;

  return true;
end;
$deletion_ready$;

revoke all on function public.assert_account_deletion_ready()
  from public, anon, authenticated;
grant execute on function public.assert_account_deletion_ready()
  to service_role;

commit;
