\set ON_ERROR_STOP on
\pset pager off

\echo SECTION migration_history
select version, name
from supabase_migrations.schema_migrations
order by version;

\echo SECTION public_table_summary
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
order by c.relname;

\echo SECTION contract_columns
select
  table_name,
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'training_sessions',
    'training_templates',
    'ai_memories',
    'ai_suggestions',
    'ai_suggestion_feedback',
    'client_operations',
    'app_feature_flags'
  )
order by table_name, ordinal_position;

\echo SECTION foreign_keys
select
  source_table.relname as table_name,
  constraint_row.conname as constraint_name,
  pg_catalog.pg_get_constraintdef(constraint_row.oid, true) as definition
from pg_catalog.pg_constraint constraint_row
join pg_catalog.pg_class source_table
  on source_table.oid = constraint_row.conrelid
join pg_catalog.pg_namespace source_schema
  on source_schema.oid = source_table.relnamespace
where source_schema.nspname = 'public'
  and constraint_row.contype = 'f'
order by source_table.relname, constraint_row.conname;

\echo SECTION check_constraints
select
  source_table.relname as table_name,
  constraint_row.conname as constraint_name,
  constraint_row.convalidated as validated,
  pg_catalog.pg_get_constraintdef(constraint_row.oid, true) as definition
from pg_catalog.pg_constraint constraint_row
join pg_catalog.pg_class source_table
  on source_table.oid = constraint_row.conrelid
join pg_catalog.pg_namespace source_schema
  on source_schema.oid = source_table.relnamespace
where source_schema.nspname = 'public'
  and constraint_row.contype = 'c'
order by source_table.relname, constraint_row.conname;

\echo SECTION triggers
select
  event_object_table as table_name,
  trigger_name,
  action_timing,
  event_manipulation,
  action_statement
from information_schema.triggers
where trigger_schema = 'public'
order by event_object_table, trigger_name, event_manipulation;

\echo SECTION policies
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_catalog.pg_policies
where schemaname = 'public'
order by tablename, policyname;

\echo SECTION function_contracts
select
  namespace_row.nspname,
  procedure_row.proname,
  pg_catalog.pg_get_function_identity_arguments(procedure_row.oid) as arguments,
  pg_catalog.pg_get_function_result(procedure_row.oid) as result,
  procedure_row.prosecdef as security_definer,
  procedure_row.proconfig as configuration,
  pg_catalog.array_to_string(procedure_row.proacl, ',') as acl
from pg_catalog.pg_proc procedure_row
join pg_catalog.pg_namespace namespace_row
  on namespace_row.oid = procedure_row.pronamespace
where namespace_row.nspname = 'public'
  and procedure_row.proname in (
    'get_daily_summary',
    'get_weekly_summary',
    'assert_account_deletion_ready',
    'goat_set_updated_at'
  )
order by procedure_row.proname,
  pg_catalog.pg_get_function_identity_arguments(procedure_row.oid);

\echo SECTION function_execute_matrix
select
  function_name,
  role_name,
  pg_catalog.has_function_privilege(
    role_name,
    pg_catalog.to_regprocedure(function_name),
    'EXECUTE'
  ) as can_execute
from (
  values
    ('public.get_daily_summary(date)'),
    ('public.get_weekly_summary(date)'),
    ('public.assert_account_deletion_ready()')
) as functions(function_name)
cross join (
  values ('PUBLIC'), ('anon'), ('authenticated'), ('service_role')
) as roles(role_name)
order by function_name, role_name;

\echo SECTION orphan_counts
select 'training_sessions' as table_name, count(*)::bigint as orphan_count
from public.training_sessions row_data
left join auth.users auth_user on auth_user.id = row_data.user_id
where auth_user.id is null
union all
select 'training_templates', count(*)::bigint
from public.training_templates row_data
left join auth.users auth_user on auth_user.id = row_data.user_id
where auth_user.id is null
union all
select 'ai_memories', count(*)::bigint
from public.ai_memories row_data
left join auth.users auth_user on auth_user.id = row_data.user_id
where auth_user.id is null
union all
select 'ai_suggestions', count(*)::bigint
from public.ai_suggestions row_data
left join auth.users auth_user on auth_user.id = row_data.user_id
where auth_user.id is null
union all
select 'ai_suggestion_feedback', count(*)::bigint
from public.ai_suggestion_feedback row_data
left join auth.users auth_user on auth_user.id = row_data.user_id
where auth_user.id is null
order by table_name;

\echo SECTION feature_flags
select key, enabled
from public.app_feature_flags
order by key;

\echo SECTION object_counts
select
  (select count(*) from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')) as table_count,
  (select count(*) from pg_catalog.pg_policies where schemaname = 'public') as policy_count,
  (select count(*) from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public') as function_count,
  (select count(*) from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and not t.tgisinternal) as trigger_count,
  (select count(*) from public.app_feature_flags) as flag_count;
