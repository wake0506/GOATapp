/*
Purpose: Read-only verification of schema, actual RLS expressions, RPC security and legacy preservation.
Read-only: Yes.
Data modification: None.
Expected time: Under 20 seconds for the supplied baseline.
Success: Every required check is PASS; REVIEW items are explicitly documented before production use.
Failure/retry: Safe to rerun. Stop deployment if any FAIL appears.
*/

-- 1. Tables and important columns.
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
    ('user_profiles', 'current_weight', 'numeric'),
    ('daily_tracking', 'water_ml', 'integer'),
    ('daily_tracking', 'weight_kg', 'numeric'),
    ('water_intake_records', 'recorded_at', 'timestamp with time zone'),
    ('water_intake_records', 'amount_ml', 'integer'),
    ('body_weight_logs', 'weight_kg', 'numeric'),
    ('client_operations', 'operation_id', 'text'),
    ('client_operations', 'claimed_at', 'timestamp with time zone')
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

-- 2. RLS is enabled, including the optional existing chat_history table.
with expected(table_name) as (
  values
    ('user_profiles'), ('food_dictionary'), ('diet_logs'),
    ('exercise_logs'), ('daily_tracking'), ('water_intake_records'),
    ('body_weight_logs'), ('training_sessions'), ('sync_tombstones'),
    ('client_operations'), ('ai_usage_daily'), ('chat_history')
)
select 'rls:' || e.table_name as check_name,
       case when c.relname is null then 'REVIEW'
            when c.relrowsecurity then 'PASS' else 'FAIL' end as status,
       case when c.relname is null then 'optional table is absent'
            when c.relrowsecurity then 'RLS enabled' else 'RLS disabled' end as details
from expected e
left join pg_namespace n on n.nspname = 'public'
left join pg_class c on c.relname = e.table_name and c.relnamespace = n.oid
order by e.table_name;

-- 3. Verify actual policy conditions, never policy names or policy counts.
with expected(table_name, column_name, command, non_ai_guard) as (
  values
    ('user_profiles', 'id', 'SELECT', false),
    ('user_profiles', 'id', 'INSERT', false),
    ('user_profiles', 'id', 'UPDATE', false),
    ('user_profiles', 'id', 'DELETE', false),
    ('food_dictionary', 'user_id', 'SELECT', false),
    ('food_dictionary', 'user_id', 'INSERT', false),
    ('food_dictionary', 'user_id', 'UPDATE', false),
    ('food_dictionary', 'user_id', 'DELETE', false),
    ('diet_logs', 'user_id', 'SELECT', false),
    ('diet_logs', 'user_id', 'INSERT', false),
    ('diet_logs', 'user_id', 'UPDATE', false),
    ('diet_logs', 'user_id', 'DELETE', false),
    ('exercise_logs', 'user_id', 'SELECT', false),
    ('exercise_logs', 'user_id', 'INSERT', false),
    ('exercise_logs', 'user_id', 'UPDATE', false),
    ('exercise_logs', 'user_id', 'DELETE', false),
    ('daily_tracking', 'user_id', 'SELECT', false),
    ('daily_tracking', 'user_id', 'INSERT', false),
    ('daily_tracking', 'user_id', 'UPDATE', false),
    ('daily_tracking', 'user_id', 'DELETE', false),
    ('water_intake_records', 'user_id', 'SELECT', false),
    ('water_intake_records', 'user_id', 'INSERT', false),
    ('water_intake_records', 'user_id', 'UPDATE', false),
    ('water_intake_records', 'user_id', 'DELETE', false),
    ('body_weight_logs', 'user_id', 'SELECT', false),
    ('body_weight_logs', 'user_id', 'INSERT', false),
    ('body_weight_logs', 'user_id', 'UPDATE', false),
    ('body_weight_logs', 'user_id', 'DELETE', false),
    ('training_sessions', 'user_id', 'SELECT', false),
    ('training_sessions', 'user_id', 'INSERT', false),
    ('training_sessions', 'user_id', 'UPDATE', false),
    ('training_sessions', 'user_id', 'DELETE', false),
    ('sync_tombstones', 'user_id', 'SELECT', false),
    ('sync_tombstones', 'user_id', 'INSERT', false),
    ('sync_tombstones', 'user_id', 'UPDATE', false),
    ('sync_tombstones', 'user_id', 'DELETE', false),
    ('client_operations', 'user_id', 'SELECT', false),
    ('client_operations', 'user_id', 'INSERT', true),
    ('client_operations', 'user_id', 'UPDATE', true),
    ('client_operations', 'user_id', 'DELETE', true),
    ('chat_history', 'user_id', 'SELECT', false),
    ('chat_history', 'user_id', 'INSERT', false),
    ('chat_history', 'user_id', 'UPDATE', false),
    ('chat_history', 'user_id', 'DELETE', false)
), policy_text as (
  select p.tablename,
    upper(trim(coalesce(p.cmd, ''))) as cmd,
    upper(trim(coalesce(p.permissive, ''))) as permissive,
    regexp_replace(lower(coalesce(p.qual, '')), '[[:space:]()]', '', 'g') as qual_text,
    regexp_replace(lower(coalesce(p.with_check, '')), '[[:space:]()]', '', 'g') as check_text,
    case when regexp_replace(lower(coalesce(p.with_check, '')), '[[:space:]()]', '', 'g') = ''
      then regexp_replace(lower(coalesce(p.qual, '')), '[[:space:]()]', '', 'g')
      else regexp_replace(lower(coalesce(p.with_check, '')), '[[:space:]()]', '', 'g')
    end as effective_check
  from pg_policies p
  where p.schemaname = 'public'
)
select 'policy:' || e.table_name || ':' || e.command as check_name,
       case when not exists (select 1 from information_schema.tables t
                             where t.table_schema = 'public' and t.table_name = e.table_name)
                 then 'REVIEW'
            when exists (
              select 1 from policy_text p
              where p.tablename = e.table_name
                and p.permissive = 'PERMISSIVE'
                and p.cmd in (e.command, 'ALL')
                and (
                  (e.command = 'SELECT' and
                   (position('auth.uid=' || e.column_name in p.qual_text) > 0
                    or position(e.column_name || '=auth.uid' in p.qual_text) > 0))
                  or (e.command = 'INSERT' and
                   (position('auth.uid=' || e.column_name in p.effective_check) > 0
                    or position(e.column_name || '=auth.uid' in p.effective_check) > 0)
                   and (not e.non_ai_guard or position('entity_type<>''nutrition-ai''' in p.effective_check) > 0))
                  or (e.command = 'UPDATE' and
                   (position('auth.uid=' || e.column_name in p.qual_text) > 0
                    or position(e.column_name || '=auth.uid' in p.qual_text) > 0)
                   and (position('auth.uid=' || e.column_name in p.effective_check) > 0
                    or position(e.column_name || '=auth.uid' in p.effective_check) > 0)
                   and (not e.non_ai_guard or
                        (position('entity_type<>''nutrition-ai''' in p.qual_text) > 0
                         and position('entity_type<>''nutrition-ai''' in p.effective_check) > 0)))
                  or (e.command = 'DELETE' and
                   (position('auth.uid=' || e.column_name in p.qual_text) > 0
                    or position(e.column_name || '=auth.uid' in p.qual_text) > 0)
                   and (not e.non_ai_guard or position('entity_type<>''nutrition-ai''' in p.qual_text) > 0))
                )
            ) then 'PASS' else 'FAIL' end as status,
       'actual cmd/using/with_check expression required' as details
from expected e
order by e.table_name, e.command;

select 'policy:ai_usage_daily:write_denied' as check_name,
       case when exists (
         select 1 from pg_policies
         where schemaname = 'public' and tablename = 'ai_usage_daily'
           and upper(trim(coalesce(permissive, ''))) = 'PERMISSIVE'
           and upper(trim(coalesce(cmd, ''))) in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
       ) then 'FAIL' else 'PASS' end as status,
       'ordinary authenticated users have no direct write policy' as details;

select 'policy:ai_usage_daily:select_own' as check_name,
       case when exists (
         select 1 from pg_policies
         where schemaname = 'public' and tablename = 'ai_usage_daily'
           and upper(trim(coalesce(permissive, ''))) = 'PERMISSIVE'
           and upper(trim(coalesce(cmd, ''))) in ('SELECT', 'ALL')
           and (
             position('auth.uid=user_id' in
               regexp_replace(lower(coalesce(qual, '')), '[[:space:]()]', '', 'g')) > 0
             or position('user_id=auth.uid' in
               regexp_replace(lower(coalesce(qual, '')), '[[:space:]()]', '', 'g')) > 0
           )
       ) then 'PASS' else 'FAIL' end as status,
       'read access is limited to auth.uid() = user_id' as details;

select 'policy:client_operations:nutrition_ai_write_guard' as check_name,
       case when exists (
         select 1 from pg_policies
         where schemaname = 'public' and tablename = 'client_operations'
           and upper(trim(coalesce(permissive, ''))) = 'PERMISSIVE'
           and upper(trim(coalesce(cmd, ''))) in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
           and (
             (upper(trim(coalesce(cmd, ''))) in ('INSERT', 'UPDATE', 'ALL') and
              position('entity_type<>''nutrition-ai''' in
                case when regexp_replace(lower(coalesce(with_check, '')), '[[:space:]()]', '', 'g') = ''
                  then regexp_replace(lower(coalesce(qual, '')), '[[:space:]()]', '', 'g')
                  else regexp_replace(lower(coalesce(with_check, '')), '[[:space:]()]', '', 'g') end) = 0)
             or (upper(trim(coalesce(cmd, ''))) in ('UPDATE', 'DELETE', 'ALL') and
              position('entity_type<>''nutrition-ai''' in
                regexp_replace(lower(coalesce(qual, '')), '[[:space:]()]', '', 'g')) = 0)
           )
       ) then 'FAIL' else 'PASS' end as status,
       'nutrition-ai rows require server RPCs' as details;

-- No safe policy may mask another permissive policy. ALL is applicable to each
-- command, and an empty with_check falls back to the policy qual expression.
with policy_text as (
  select p.tablename,
    upper(trim(coalesce(p.cmd, ''))) as cmd,
    upper(trim(coalesce(p.permissive, ''))) as permissive,
    regexp_replace(lower(coalesce(p.qual, '')), '[[:space:]()]', '', 'g') as qual_text,
    regexp_replace(lower(coalesce(p.with_check, '')), '[[:space:]()]', '', 'g') as check_text
  from pg_policies p where p.schemaname = 'public'
), expected(table_name, column_name, non_ai_guard) as (
  values
    ('user_profiles', 'id', false), ('food_dictionary', 'user_id', false),
    ('diet_logs', 'user_id', false), ('exercise_logs', 'user_id', false),
    ('daily_tracking', 'user_id', false), ('water_intake_records', 'user_id', false),
    ('body_weight_logs', 'user_id', false), ('training_sessions', 'user_id', false),
    ('sync_tombstones', 'user_id', false), ('client_operations', 'user_id', true),
    ('chat_history', 'user_id', false)
)
select 'policy:' || e.table_name || ':no_broad_permissive' as check_name,
       case when not exists (
         select 1 from policy_text p
         where p.tablename = e.table_name and p.permissive = 'PERMISSIVE'
           and (
             (p.cmd in ('SELECT', 'ALL') and not (
               position('auth.uid=' || e.column_name in p.qual_text) > 0
               or position(e.column_name || '=auth.uid' in p.qual_text) > 0))
             or (p.cmd in ('INSERT', 'ALL') and not (
               (position('auth.uid=' || e.column_name in
                 case when p.check_text = '' then p.qual_text else p.check_text end) > 0
                or position(e.column_name || '=auth.uid' in
                 case when p.check_text = '' then p.qual_text else p.check_text end) > 0)
               and (not e.non_ai_guard or position('entity_type<>''nutrition-ai''' in
                 case when p.check_text = '' then p.qual_text else p.check_text end) > 0)))
             or (p.cmd in ('UPDATE', 'ALL') and not (
               (position('auth.uid=' || e.column_name in p.qual_text) > 0
                or position(e.column_name || '=auth.uid' in p.qual_text) > 0)
               and (position('auth.uid=' || e.column_name in
                 case when p.check_text = '' then p.qual_text else p.check_text end) > 0
                or position(e.column_name || '=auth.uid' in
                 case when p.check_text = '' then p.qual_text else p.check_text end) > 0)
               and (not e.non_ai_guard or
                 (position('entity_type<>''nutrition-ai''' in p.qual_text) > 0
                  and position('entity_type<>''nutrition-ai''' in
                    case when p.check_text = '' then p.qual_text else p.check_text end) > 0))))
             or (p.cmd in ('DELETE', 'ALL') and not (
               (position('auth.uid=' || e.column_name in p.qual_text) > 0
                or position(e.column_name || '=auth.uid' in p.qual_text) > 0)
               and (not e.non_ai_guard or position('entity_type<>''nutrition-ai''' in p.qual_text) > 0)))
           )
       ) then 'PASS' else 'FAIL' end as status,
       'every applicable PERMISSIVE policy must be own-row safe' as details
from expected e
order by e.table_name;

-- 4. Constraints must exist and be validated, not merely present as NOT VALID.
with expected(table_name, constraint_name) as (
  values
    ('user_profiles', 'user_profiles_weight_range'),
    ('food_dictionary', 'food_dictionary_nutrition_nonnegative'),
    ('diet_logs', 'diet_logs_nutrition_nonnegative'),
    ('diet_logs', 'diet_logs_meal_type_valid'),
    ('exercise_logs', 'exercise_logs_kcal_nonnegative'),
    ('daily_tracking', 'daily_tracking_water_nonnegative'),
    ('daily_tracking', 'daily_tracking_weight_range'),
    ('water_intake_records', 'water_intake_amount_range'),
    ('body_weight_logs', 'body_weight_range'),
    ('ai_usage_daily', 'ai_usage_nonnegative'),
    ('client_operations', 'client_operations_action_valid')
)
select 'constraint:' || e.table_name || ':' || e.constraint_name as check_name,
       case when c.oid is null then 'FAIL'
            when c.convalidated then 'PASS' else 'FAIL' end as status,
       coalesce(pg_get_constraintdef(c.oid), 'missing') ||
         ' / convalidated=' || coalesce(c.convalidated::text, 'false') as details
from expected e
left join pg_constraint c
  on c.conname = e.constraint_name
 and c.conrelid = ('public.' || e.table_name)::regclass
order by e.table_name, e.constraint_name;

-- 5. Triggers, indexes and operation uniqueness.
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
           and t.tgname = e.table_name || '_updated_at' and not t.tgisinternal
       ) then 'PASS' else 'FAIL' end as status,
       'updated_at trigger exists' as details
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
    ('training_sessions_updated_idx'), ('sync_tombstones_updated_idx'),
    ('client_operations_nutrition_lease_idx')
)
select 'index:' || e.index_name as check_name,
       case when i.indexname is null then 'FAIL' else 'PASS' end as status,
       coalesce(i.indexdef, 'missing') as details
from expected e
left join pg_indexes i on i.schemaname = 'public' and i.indexname = e.index_name
order by e.index_name;

select 'duplicate_operation_ids' as check_name,
       case when exists (
         select 1 from public.client_operations
         group by user_id, operation_id having count(*) > 1
       ) then 'FAIL' else 'PASS' end as status,
       'primary key (user_id, operation_id)' as details;

-- 6. SECURITY DEFINER, fixed search_path and execute privileges for all AI RPCs.
with expected(function_name, signature) as (
  values
    ('consume_ai_quota', 'public.consume_ai_quota()'),
    ('nutrition_ai_get_cached_response', 'public.nutrition_ai_get_cached_response(text)'),
    ('nutrition_ai_claim_operation', 'public.nutrition_ai_claim_operation(text)'),
    ('nutrition_ai_save_response', 'public.nutrition_ai_save_response(text,jsonb)'),
    ('nutrition_ai_release_operation', 'public.nutrition_ai_release_operation(text)')
), funcs as (
  select e.*, to_regprocedure(e.signature) as oid from expected e
)
select 'rpc:' || f.function_name as check_name,
       case when f.oid is null then 'FAIL'
            when not p.prosecdef then 'FAIL'
            when not (p.proconfig @> array['search_path=public']) then 'FAIL'
            when not coalesce(has_function_privilege('authenticated', f.oid, 'EXECUTE'), false) then 'FAIL'
            when coalesce(has_function_privilege('anon', f.oid, 'EXECUTE'), false) then 'FAIL'
            else 'PASS' end as status,
       case when f.oid is null then 'function is missing'
            else 'SECURITY DEFINER, search_path=public, authenticated-only execute' end as details
from funcs f
left join pg_proc p on p.oid = f.oid
order by f.function_name;

select 'rpc:consume_ai_quota:fixed_signature' as check_name,
       case when to_regprocedure('public.consume_ai_quota(uuid,date,integer)') is null
                 then 'PASS' else 'REVIEW' end as status,
       'old overload may remain only with execute revoked from client roles' as details;

with old_rpc as (
  select to_regprocedure('public.consume_ai_quota(uuid,date,integer)') as oid
)
select 'rpc:old_consume_ai_quota:public_execute' as check_name,
       case when o.oid is null then 'PASS'
            when exists (
              select 1 from pg_proc p
              cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
              where p.oid = o.oid and a.grantee = 0 and a.privilege_type = 'EXECUTE'
            ) then 'FAIL' else 'PASS' end as status,
       'PUBLIC must not execute the client-parameterized overload' as details
from old_rpc o;

with old_rpc as (
  select to_regprocedure('public.consume_ai_quota(uuid,date,integer)') as oid
)
select 'rpc:old_consume_ai_quota:anon_authenticated_execute' as check_name,
       case when o.oid is null then 'PASS'
            when coalesce(has_function_privilege('anon', o.oid, 'EXECUTE'), false)
              or coalesce(has_function_privilege('authenticated', o.oid, 'EXECUTE'), false)
              then 'FAIL' else 'PASS' end as status,
       'anon and authenticated must not execute the client-parameterized overload' as details
from old_rpc o;

with expected as (
  select to_regprocedure('public.nutrition_ai_claim_operation(text)') as oid
)
select 'rpc:nutrition_ai_claim_operation:lease' as check_name,
       case when e.oid is null then 'FAIL'
            when position('2 minutes' in pg_get_functiondef(p.oid)) > 0 then 'PASS'
            else 'FAIL' end as status,
       'pending rows older than two minutes may be reclaimed by the same user' as details
from expected e
left join pg_proc p on p.oid = e.oid;

-- 7. Baseline preservation. Values are from the confirmed preflight.
with checks(check_name, actual_count, expected_count) as (
  values
    ('baseline:user_profiles', (select count(*) from public.user_profiles), 1::bigint),
    ('baseline:food_dictionary', (select count(*) from public.food_dictionary), 0::bigint),
    ('baseline:diet_logs', (select count(*) from public.diet_logs), 0::bigint),
    ('baseline:exercise_logs', (select count(*) from public.exercise_logs), 0::bigint),
    ('baseline:daily_tracking', (select count(*) from public.daily_tracking), 2::bigint),
    ('baseline:chat_history', (select count(*) from public.chat_history), 1::bigint)
)
select check_name,
       case when actual_count < expected_count then 'FAIL'
            when actual_count = expected_count then 'PASS' else 'REVIEW' end as status,
       'actual=' || actual_count::text || ', expected minimum=' || expected_count::text as details
from checks;

with column_meta as (
  select coalesce(max(data_type), 'missing') as data_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'user_profiles'
    and column_name = 'training_data'
), values_checked as (
  select count(*) filter (
    where training_data is not null and btrim(training_data::text) <> ''
  ) as text_nonempty,
  count(*) filter (
    where training_data is not null and btrim(training_data::text) <> '[]'
  ) as json_nonempty
  from public.user_profiles
)
select 'baseline:training_data_nonempty' as check_name,
       case when m.data_type = 'text' and v.text_nonempty >= 1 then 'PASS'
            when m.data_type = 'jsonb' and v.json_nonempty >= 1 then 'PASS'
            when m.data_type in ('text', 'jsonb') then 'FAIL'
            when m.data_type is null then 'FAIL'
            else 'REVIEW' end as status,
       'data_type=' || coalesce(m.data_type, 'missing') ||
         ', text_nonempty=' || v.text_nonempty::text ||
         ', jsonb_nonempty=' || v.json_nonempty::text as details
from column_meta m cross join values_checked v;

select 'baseline:legacy_water_rows' as check_name,
       case when count(*) < 1 then 'FAIL'
            when count(*) = 1 then 'PASS' else 'REVIEW' end as status,
       'legacy rows=' || count(*)::text || ', expected=1' as details
from public.water_intake_records
where is_legacy_aggregate = true;

select 'baseline:legacy_water_total' as check_name,
       case when coalesce(sum(amount_ml), 0) < 300 then 'FAIL'
            when coalesce(sum(amount_ml), 0) = 300 then 'PASS' else 'REVIEW' end as status,
       'legacy total=' || coalesce(sum(amount_ml), 0)::text || ' ml, expected=300 ml' as details
from public.water_intake_records
where is_legacy_aggregate = true;

select 'baseline:daily_tracking_water_compatibility' as check_name,
       case when coalesce(sum(water_ml), 0) = 300 then 'PASS'
            when coalesce(sum(water_ml), 0) < 300 then 'FAIL' else 'REVIEW' end as status,
       'daily_tracking total=' || coalesce(sum(water_ml), 0)::text || ' ml, expected=300 ml' as details
from public.daily_tracking;

select 'baseline:legacy_weight_rows' as check_name,
       case when count(*) < 2 then 'FAIL'
            when count(*) = 2 then 'PASS' else 'REVIEW' end as status,
       'legacy rows=' || count(*)::text || ', expected=2' as details
from public.body_weight_logs
where id like 'legacy_weight_%';

-- 8. Foreign-key ownership integrity.
select 'orphan_user_ids' as check_name,
       case when exists (
         select 1 from public.user_profiles p where not exists (select 1 from auth.users u where u.id = p.id)
       ) or exists (
         select 1 from public.food_dictionary f where not exists (select 1 from auth.users u where u.id = f.user_id)
       ) or exists (
         select 1 from public.diet_logs d where not exists (select 1 from auth.users u where u.id = d.user_id)
       ) or exists (
         select 1 from public.exercise_logs e where not exists (select 1 from auth.users u where u.id = e.user_id)
       ) or exists (
         select 1 from public.daily_tracking d where not exists (select 1 from auth.users u where u.id = d.user_id)
       ) or exists (
         select 1 from public.water_intake_records w where not exists (select 1 from auth.users u where u.id = w.user_id)
       ) or exists (
         select 1 from public.body_weight_logs b where not exists (select 1 from auth.users u where u.id = b.user_id)
       ) or exists (
         select 1 from public.training_sessions t where not exists (select 1 from auth.users u where u.id = t.user_id)
       ) or exists (
         select 1 from public.sync_tombstones s where not exists (select 1 from auth.users u where u.id = s.user_id)
       ) or exists (
         select 1 from public.client_operations o where not exists (select 1 from auth.users u where u.id = o.user_id)
       ) or exists (
         select 1 from public.ai_usage_daily a where not exists (select 1 from auth.users u where u.id = a.user_id)
       ) then 'FAIL' else 'PASS' end as status,
       'all user-owned tables checked' as details;
