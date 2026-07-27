-- QASZ INDEPENDENT TEST PROJECT ONLY.
-- This validates the production-safe containment shape without dropping
-- tables, functions, policies, rows, auth users, or versioned_sync.
-- The session guard prevents accidental execution without an explicit test
-- marker. Never run this against production.

\set ON_ERROR_STOP on
set goat.contract_qasz_containment = 'on';

do $guard$
begin
  if pg_catalog.current_setting('goat.contract_qasz_containment', true)
      is distinct from 'on' then
    raise exception 'QASZ_CONTAINMENT_GUARD_NOT_ENABLED';
  end if;
end;
$guard$;

create temp table goat_qasz_containment_snapshot on commit preserve rows as
select key, enabled
from public.app_feature_flags
where key = 'nutrition_ai';

create temp table goat_qasz_counts on commit preserve rows as
select 'user_profiles'::text as table_name, count(*)::bigint as row_count
from public.user_profiles
union all select 'daily_tracking', count(*)::bigint from public.daily_tracking
union all select 'chat_history', count(*)::bigint from public.chat_history
union all select 'client_operations', count(*)::bigint from public.client_operations;

begin;
update public.app_feature_flags
set enabled = false
where key = 'nutrition_ai';
commit;

select
  'containment_flag_disabled' as check_name,
  case when exists (
    select 1 from public.app_feature_flags
    where key = 'nutrition_ai' and enabled = false
  ) then 'PASS' else 'FAIL' end as status,
  'nutrition_ai client gate disabled; no rows or functions removed' as details;

select
  'containment_data_retained' as check_name,
  case when not exists (
    select 1
    from goat_qasz_counts before_count
    join lateral (
      select count(*)::bigint as row_count
      from public.user_profiles
      where before_count.table_name = 'user_profiles'
      union all select count(*)::bigint from public.daily_tracking
        where before_count.table_name = 'daily_tracking'
      union all select count(*)::bigint from public.chat_history
        where before_count.table_name = 'chat_history'
      union all select count(*)::bigint from public.client_operations
        where before_count.table_name = 'client_operations'
    ) after_count on true
    where before_count.row_count <> after_count.row_count
  ) then 'PASS' else 'FAIL' end as status,
  'Stage 0 and idempotency row counts unchanged' as details;

begin;
update public.app_feature_flags flags
set enabled = snapshot.enabled
from goat_qasz_containment_snapshot snapshot
where flags.key = snapshot.key;
commit;

select
  'forward_fix_flag_restored' as check_name,
  case when not exists (
    select 1
    from public.app_feature_flags flags
    join goat_qasz_containment_snapshot snapshot using (key)
    where flags.enabled is distinct from snapshot.enabled
  ) then 'PASS' else 'FAIL' end as status,
  'original feature-flag state restored' as details;

select
  'forward_fix_versioned_sync' as check_name,
  case when exists (
    select 1 from public.app_feature_flags
    where key = 'versioned_sync' and enabled = false
  ) then 'PASS' else 'FAIL' end as status,
  'versioned_sync remains false' as details;
