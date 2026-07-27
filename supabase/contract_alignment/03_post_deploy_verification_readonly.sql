/*
Read-only post-deploy verification for the independent test project and,
after explicit approval, production.
*/

with expected_tables(table_name) as (
  values
    ('training_templates'),
    ('ai_memories'),
    ('ai_suggestions'),
    ('ai_suggestion_feedback')
),
table_checks as (
  select
    'table:' || expected.table_name as check_name,
    case
      when catalog_table.oid is null then 'FAIL'
      when catalog_table.relrowsecurity is not true then 'FAIL'
      else 'PASS'
    end as status,
    case
      when catalog_table.oid is null then 'missing'
      when catalog_table.relrowsecurity is not true then 'RLS disabled'
      else 'present with RLS'
    end as details
  from expected_tables expected
  left join pg_catalog.pg_namespace table_schema
    on table_schema.nspname = 'public'
  left join pg_catalog.pg_class catalog_table
    on catalog_table.relnamespace = table_schema.oid
   and catalog_table.relname = expected.table_name
   and catalog_table.relkind = 'r'
),
policy_checks as (
  select
    'policies:' || expected.table_name as check_name,
    case
      when pg_catalog.count(policy_row.policyname) filter (
        where policy_row.cmd in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
          and policy_row.roles = array['authenticated']::name[]
      ) = 4 then 'PASS'
      else 'FAIL'
    end as status,
    pg_catalog.format(
      '%s authenticated CRUD policies',
      pg_catalog.count(policy_row.policyname) filter (
        where policy_row.cmd in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
          and policy_row.roles = array['authenticated']::name[]
      )
    ) as details
  from expected_tables expected
  left join pg_catalog.pg_policies policy_row
    on policy_row.schemaname = 'public'
   and policy_row.tablename = expected.table_name
  group by expected.table_name
),
trigger_checks as (
  select
    'trigger:' || expected.table_name || '_updated_at' as check_name,
    case when pg_catalog.count(trigger_row.oid) = 1 then 'PASS' else 'FAIL' end as status,
    pg_catalog.format('%s matching trigger(s)', pg_catalog.count(trigger_row.oid)) as details
  from expected_tables expected
  left join pg_catalog.pg_class table_row
    on table_row.oid = pg_catalog.to_regclass(
      pg_catalog.format('public.%I', expected.table_name)
    )
  left join pg_catalog.pg_trigger trigger_row
    on trigger_row.tgrelid = table_row.oid
   and trigger_row.tgname = expected.table_name || '_updated_at'
   and not trigger_row.tgisinternal
  group by expected.table_name
),
fk_checks as (
  select
    'delete_cascade:' || expected.table_name as check_name,
    case when exists (
      select 1
      from pg_catalog.pg_constraint constraint_row
      where constraint_row.conrelid = pg_catalog.to_regclass(
        pg_catalog.format('public.%I', expected.table_name)
      )
        and constraint_row.contype = 'f'
        and constraint_row.confrelid = pg_catalog.to_regclass('auth.users')
        and constraint_row.confdeltype = 'c'
    ) then 'PASS' else 'FAIL' end as status,
    'user ownership FK must cascade from auth.users' as details
  from expected_tables expected
),
fixed_checks as (
  select
    'training_sessions:exercises_constraint'::text as check_name,
    case when exists (
      select 1
      from pg_catalog.pg_constraint constraint_row
      where constraint_row.conrelid = pg_catalog.to_regclass('public.training_sessions')
        and constraint_row.conname = 'training_sessions_exercises_array'
        and constraint_row.convalidated
    ) then 'PASS' else 'FAIL' end as status,
    'validated JSON array constraint'::text as details
  union all
  select
    'versioned_sync:disabled',
    case when exists (
      select 1
      from public.app_feature_flags flag_row
      where flag_row.key = 'versioned_sync'
        and flag_row.enabled = false
    ) then 'PASS' else 'FAIL' end,
    'must remain false'
  union all
  select
    'delete_account:service_role_only',
    case when pg_catalog.has_function_privilege(
      'service_role',
      'public.assert_account_deletion_ready()',
      'EXECUTE'
    )
    and not pg_catalog.has_function_privilege(
      'anon',
      'public.assert_account_deletion_ready()',
      'EXECUTE'
    )
    and not pg_catalog.has_function_privilege(
      'authenticated',
      'public.assert_account_deletion_ready()',
      'EXECUTE'
    ) then 'PASS' else 'FAIL' end,
    'readiness RPC must be service-role only'
)
select check_name, status, details from table_checks
union all
select check_name, status, details from policy_checks
union all
select check_name, status, details from trigger_checks
union all
select check_name, status, details from fk_checks
union all
select check_name, status, details from fixed_checks
order by check_name;
