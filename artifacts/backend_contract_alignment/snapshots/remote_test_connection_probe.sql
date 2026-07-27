\set ON_ERROR_STOP on
\pset pager off
\echo SECTION connection
select current_database() = 'postgres' as database_is_postgres;
select current_user is not null as authenticated_connection;
select current_setting('server_version') as server_version;
\echo SECTION migration_history
select pg_catalog.to_regclass('supabase_migrations.schema_migrations') as migration_history_table;
\echo SECTION object_counts
select
  (select count(*) from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind in ('r', 'p')) as public_table_count,
  (select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public') as public_function_count,
  (select count(*) from pg_catalog.pg_trigger t join pg_catalog.pg_class c on c.oid = t.tgrelid join pg_catalog.pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and not t.tgisinternal) as public_trigger_count,
  (select count(*) from auth.users) as auth_user_count;
\echo SECTION stage0_objects
select object_name, exists_flag
from (
  values
    ('user_profiles', pg_catalog.to_regclass('public.user_profiles') is not null),
    ('training_sessions', pg_catalog.to_regclass('public.training_sessions') is not null),
    ('client_operations', pg_catalog.to_regclass('public.client_operations') is not null),
    ('app_feature_flags', pg_catalog.to_regclass('public.app_feature_flags') is not null)
) as objects(object_name, exists_flag)
order by object_name;
\echo SECTION stage0_counts
select 'user_profiles' as table_name, count(*)::bigint as row_count from public.user_profiles
union all select 'training_sessions', count(*)::bigint from public.training_sessions
union all select 'client_operations', count(*)::bigint from public.client_operations
union all select 'app_feature_flags', count(*)::bigint from public.app_feature_flags
order by table_name;
select exists (
  select 1 from public.app_feature_flags where key = 'versioned_sync' and enabled = false
) as versioned_sync_disabled;
