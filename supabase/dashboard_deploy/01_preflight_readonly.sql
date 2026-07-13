/*
Purpose: Read-only inventory before the GOATapp backend extension.
Read-only: Yes.
Data modification: None.
Expected time: Under 10 seconds.
Success: Result sets show existing tables, fields, RLS, policies, indexes,
         constraints and legacy columns without errors.
Failure/retry: Safe to rerun. Stop and review any unexpected policy/object.
*/

select 'PRECHECK' as section, current_database() as database_name,
       current_user as database_role, now() as checked_at;

with expected(table_name) as (
  values
    ('user_profiles'), ('food_dictionary'), ('diet_logs'),
    ('exercise_logs'), ('daily_tracking'), ('water_intake_records'),
    ('body_weight_logs'), ('training_sessions'), ('sync_tombstones'),
    ('client_operations'), ('ai_usage_daily'), ('chat_history')
)
select e.table_name,
       case when t.table_name is null then 'MISSING' else 'EXISTS' end as status,
       t.table_type
from expected e
left join information_schema.tables t
  on t.table_schema = 'public' and t.table_name = e.table_name
order by e.table_name;

select table_name, column_name, data_type, udt_name, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations',
    'ai_usage_daily', 'chat_history'
  )
order by table_name, ordinal_position;

select c.relname as table_name,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations',
    'ai_usage_daily', 'chat_history'
  )
order by c.relname;

select schemaname, tablename, policyname, cmd, permissive, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations',
    'ai_usage_daily', 'chat_history'
  )
order by tablename, policyname;

select schemaname, tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and tablename in (
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations',
    'ai_usage_daily', 'chat_history'
  )
order by tablename, indexname;

select n.nspname as schema_name, c.relname as object_name,
       case c.relkind when 'r' then 'table' when 'v' then 'view'
            when 'm' then 'materialized view' when 'S' then 'sequence'
            when 'f' then 'foreign table' else c.relkind::text end as object_type
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations',
    'ai_usage_daily'
  )
order by c.relname;

do $$
declare
  table_name text;
  row_count bigint;
begin
  foreach table_name in array array[
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations',
    'ai_usage_daily'
  ] loop
    if to_regclass('public.' || table_name) is null then
      raise notice 'COUNT REVIEW: public.% is missing', table_name;
    else
      execute format('select count(*) from public.%I', table_name) into row_count;
      raise notice 'COUNT: public.% = %', table_name, row_count;
    end if;
  end loop;
end $$;

select 'chat_history' as object_name,
       case when to_regclass('public.chat_history') is null
            then 'ABSENT' else 'PRESENT - policy review required' end as status;

select 'legacy_columns' as check_name,
       case when exists (
         select 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'user_profiles'
           and column_name = 'training_data'
       ) then 'PRESENT' else 'MISSING' end as training_data,
       case when exists (
         select 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'daily_tracking'
           and column_name = 'water_ml'
       ) then 'PRESENT' else 'MISSING' end as daily_water,
       case when exists (
         select 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'daily_tracking'
           and column_name = 'weight_kg'
       ) then 'PRESENT' else 'MISSING' end as daily_weight;
