/*
Purpose: Read-only post-deployment verification for schema, RLS and legacy preservation.
Read-only: Yes.
Data modification: None.
Expected time: Under 15 seconds.
Success: Checks return PASS; REVIEW items are documented manual confirmations.
Failure/retry: Safe to rerun. Stop deployment if any FAIL appears.
*/

with expected(table_name) as (
  values
    ('user_profiles'), ('food_dictionary'), ('diet_logs'),
    ('exercise_logs'), ('daily_tracking'), ('water_intake_records'),
    ('body_weight_logs'), ('training_sessions'), ('sync_tombstones'),
    ('client_operations'), ('ai_usage_daily')
)
select 'table:' || e.table_name as check_name,
       case when t.table_name is null then 'FAIL' else 'PASS' end as status,
       case when t.table_name is null then 'target table is missing' else 'table exists' end as details
from expected e
left join information_schema.tables t
  on t.table_schema = 'public' and t.table_name = e.table_name
order by e.table_name;

with expected(table_name, column_name, expected_type) as (
  values
    ('user_profiles', 'training_data', 'jsonb'),
    ('user_profiles', 'current_weight', 'numeric'),
    ('daily_tracking', 'water_ml', 'integer'),
    ('daily_tracking', 'weight_kg', 'numeric'),
    ('water_intake_records', 'recorded_at', 'timestamp with time zone'),
    ('water_intake_records', 'amount_ml', 'integer'),
    ('body_weight_logs', 'weight_kg', 'numeric'),
    ('client_operations', 'operation_id', 'text')
)
select 'column:' || e.table_name || '.' || e.column_name as check_name,
       case when c.column_name is null then 'FAIL'
            when c.data_type <> e.expected_type then 'REVIEW'
            else 'PASS' end as status,
       coalesce(c.data_type, 'missing') || ' / expected ' || e.expected_type as details
from expected e
left join information_schema.columns c
  on c.table_schema = 'public'
 and c.table_name = e.table_name
 and c.column_name = e.column_name
order by e.table_name, e.column_name;

select 'rls:' || c.relname as check_name,
       case when c.relrowsecurity then 'PASS' else 'FAIL' end as status,
       case when c.relrowsecurity then 'RLS enabled' else 'RLS disabled' end as details
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

with expected(table_name, required_count) as (
  values
    ('user_profiles', 4), ('food_dictionary', 4), ('diet_logs', 4),
    ('exercise_logs', 4), ('daily_tracking', 4),
    ('water_intake_records', 4), ('body_weight_logs', 4),
    ('training_sessions', 4), ('sync_tombstones', 4),
    ('client_operations', 4), ('ai_usage_daily', 4)
), actual as (
  select tablename, count(*)::integer as policy_count
  from pg_policies
  where schemaname = 'public'
  group by tablename
)
select 'policies:' || e.table_name as check_name,
       case when coalesce(a.policy_count, 0) >= e.required_count then 'PASS' else 'FAIL' end as status,
       'found=' || coalesce(a.policy_count, 0)::text || ', required=' || e.required_count::text as details
from expected e
left join actual a on a.tablename = e.table_name
order by e.table_name;

with expected(table_name) as (
  values
    ('user_profiles'), ('food_dictionary'), ('diet_logs'),
    ('exercise_logs'), ('daily_tracking'), ('water_intake_records'),
    ('body_weight_logs'), ('training_sessions'), ('sync_tombstones'),
    ('client_operations'), ('ai_usage_daily')
)
select 'updated_at_trigger:' || e.table_name as check_name,
       case when exists (
         select 1 from pg_trigger t
         join pg_class c on c.oid = t.tgrelid
         join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relname = e.table_name
           and t.tgname = e.table_name || '_updated_at'
           and not t.tgisinternal
       ) then 'PASS' else 'FAIL' end as status,
       'named trigger check' as details
from expected e
order by e.table_name;

with expected(index_name) as (
  values
    ('food_dictionary_client_operation_idx'), ('diet_logs_client_operation_idx'),
    ('exercise_logs_client_operation_idx'), ('water_intake_records_client_operation_idx'),
    ('body_weight_logs_client_operation_idx'), ('training_sessions_client_operation_idx'),
    ('food_dictionary_updated_idx'), ('diet_logs_updated_idx'),
    ('exercise_logs_updated_idx'), ('daily_tracking_updated_idx'),
    ('water_intake_records_updated_idx'), ('body_weight_logs_updated_idx'),
    ('training_sessions_updated_idx'), ('sync_tombstones_updated_idx')
)
select 'index:' || e.index_name as check_name,
       case when i.indexname is null then 'FAIL' else 'PASS' end as status,
       coalesce(i.indexdef, 'missing') as details
from expected e
left join pg_indexes i
  on i.schemaname = 'public' and i.indexname = e.index_name
order by e.index_name;

with expected(constraint_name) as (
  values
    ('user_profiles_weight_range'), ('food_dictionary_nutrition_nonnegative'),
    ('diet_logs_nutrition_nonnegative'), ('diet_logs_meal_type_valid'),
    ('exercise_logs_kcal_nonnegative'), ('daily_tracking_water_nonnegative'),
    ('daily_tracking_weight_range'), ('water_intake_amount_range'),
    ('body_weight_range'), ('ai_usage_nonnegative'),
    ('client_operations_action_valid')
)
select 'constraint:' || e.constraint_name as check_name,
       case when c.conname is null then 'FAIL' else 'PASS' end as status,
       coalesce(pg_get_constraintdef(c.oid), 'missing') as details
from expected e
left join pg_constraint c on c.conname = e.constraint_name
order by e.constraint_name;

select 'legacy_water_total' as check_name,
       case when coalesce((select sum(amount_ml) from public.water_intake_records
                           where is_legacy_aggregate), 0)
                 >= coalesce((select sum(water_ml) from public.daily_tracking
                              where water_ml > 0), 0)
            then 'PASS' else 'FAIL' end as status,
       'detail total must not be lower than compatibility total' as details;

select 'legacy_weight_values' as check_name,
       case when exists (
         select 1 from public.daily_tracking d
         where d.weight_kg >= 20 and d.weight_kg <= 300
           and not exists (
             select 1 from public.body_weight_logs b
             where b.user_id = d.user_id and b.date = d.date
               and b.weight_kg = d.weight_kg
           )
       ) then 'FAIL' else 'PASS' end as status,
       'valid daily weights must have an equal detail value' as details;

select 'duplicate_operation_ids' as check_name,
       case when exists (
         select 1 from public.client_operations
         group by user_id, operation_id having count(*) > 1
       ) then 'FAIL' else 'PASS' end as status,
       'primary key (user_id, operation_id)' as details;

select 'orphan_user_ids' as check_name,
       case when exists (
         select 1 from public.food_dictionary f
         where not exists (select 1 from auth.users u where u.id = f.user_id)
       ) or exists (
         select 1 from public.diet_logs d
         where not exists (select 1 from auth.users u where u.id = d.user_id)
       ) or exists (
         select 1 from public.exercise_logs e
         where not exists (select 1 from auth.users u where u.id = e.user_id)
       ) or exists (
         select 1 from public.daily_tracking d
         where not exists (select 1 from auth.users u where u.id = d.user_id)
       ) or exists (
         select 1 from public.water_intake_records w
         where not exists (select 1 from auth.users u where u.id = w.user_id)
       ) or exists (
         select 1 from public.body_weight_logs b
         where not exists (select 1 from auth.users u where u.id = b.user_id)
       ) or exists (
         select 1 from public.training_sessions t
         where not exists (select 1 from auth.users u where u.id = t.user_id)
       ) or exists (
         select 1 from public.sync_tombstones s
         where not exists (select 1 from auth.users u where u.id = s.user_id)
       ) or exists (
         select 1 from public.client_operations o
         where not exists (select 1 from auth.users u where u.id = o.user_id)
       ) or exists (
         select 1 from public.ai_usage_daily a
         where not exists (select 1 from auth.users u where u.id = a.user_id)
       ) then 'FAIL' else 'PASS' end as status,
       'all user_id tables checked' as details;

select 'chat_history_policy' as check_name,
       case when to_regclass('public.chat_history') is null then 'REVIEW'
            when exists (select 1 from pg_policies where schemaname = 'public'
                        and tablename = 'chat_history'
                        and policyname = 'goat_chat_select_own') then 'PASS'
            else 'FAIL' end as status,
       'chat_history is optional in the current client schema' as details;
