\set ON_ERROR_STOP on
\pset pager off
\echo SECTION schemas
select nspname from pg_catalog.pg_namespace where nspname in ('public','auth','extensions','supabase_migrations') order by nspname;
\echo SECTION tables
select n.nspname, c.relname, c.relkind, c.relrowsecurity, c.relforcerowsecurity
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','auth') and c.relkind in ('r','p') order by n.nspname,c.relname;
\echo SECTION columns
select table_schema, table_name, column_name, data_type, is_nullable
from information_schema.columns where table_schema in ('public','auth') order by table_schema,table_name,ordinal_position;
\echo SECTION constraints
select ns.nspname, cls.relname, con.conname, con.contype, con.convalidated, pg_catalog.pg_get_constraintdef(con.oid,true)
from pg_catalog.pg_constraint con join pg_catalog.pg_class cls on cls.oid=con.conrelid join pg_catalog.pg_namespace ns on ns.oid=cls.relnamespace
where ns.nspname='public' order by cls.relname,con.conname;
\echo SECTION indexes
select schemaname, tablename, indexname, indexdef from pg_catalog.pg_indexes where schemaname='public' order by tablename,indexname;
\echo SECTION functions
select ns.nspname, p.proname, pg_catalog.pg_get_function_identity_arguments(p.oid), pg_catalog.pg_get_function_result(p.oid), p.prosecdef, p.proconfig, pg_catalog.array_to_string(p.proacl,',')
from pg_catalog.pg_proc p join pg_catalog.pg_namespace ns on ns.oid=p.pronamespace
where ns.nspname='public' order by p.proname,pg_catalog.pg_get_function_identity_arguments(p.oid);
\echo SECTION policies
select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check from pg_catalog.pg_policies where schemaname='public' order by tablename,policyname;
\echo SECTION triggers
select event_object_table,trigger_name,action_timing,event_manipulation,action_statement from information_schema.triggers where trigger_schema='public' order by event_object_table,trigger_name,event_manipulation;
\echo SECTION counts
select 'auth.users' as table_name,count(*)::bigint as row_count from auth.users
union all select 'user_profiles',count(*)::bigint from public.user_profiles
union all select 'training_sessions',count(*)::bigint from public.training_sessions
union all select 'client_operations',count(*)::bigint from public.client_operations
union all select 'app_feature_flags',count(*)::bigint from public.app_feature_flags
order by table_name;
\echo SECTION versioned_sync
select key,enabled from public.app_feature_flags where key='versioned_sync';
