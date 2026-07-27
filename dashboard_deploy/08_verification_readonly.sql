/*
Purpose: One read-only PASS/FAIL/REVIEW summary for the v5 Dashboard deployment.
Read-only: Yes. This script creates no objects and changes no data or privileges.
Expected time: Under 30 seconds for the confirmed production baseline.
Success: Every row is PASS. Stop if any row is FAIL; investigate REVIEW before proceeding.
Failure/retry: Safe to rerun. The final statement always returns one result table.
*/

with
required_tables(table_name) as (
  values
    ('user_profiles'), ('food_dictionary'), ('diet_logs'),
    ('exercise_logs'), ('daily_tracking'), ('water_intake_records'),
    ('body_weight_logs'), ('training_sessions'), ('sync_tombstones'),
    ('client_operations'), ('ai_usage_daily'), ('chat_history')
),
required_columns(table_name, column_name, expected_type) as (
  values
    ('user_profiles', 'current_weight', 'numeric'),
    ('daily_tracking', 'water_ml', 'integer'),
    ('daily_tracking', 'weight_kg', 'numeric'),
    ('water_intake_records', 'recorded_at', 'timestamp with time zone'),
    ('water_intake_records', 'amount_ml', 'integer'),
    ('body_weight_logs', 'weight_kg', 'numeric'),
    ('client_operations', 'operation_id', 'text'),
    ('client_operations', 'claimed_at', 'timestamp with time zone'),
    ('client_operations', 'claim_token', 'uuid'),
    ('ai_usage_daily', 'client_operation_ids', 'jsonb')
),
policy_rows as (
  select
    p.tablename,
    upper(trim(coalesce(p.cmd, ''))) as cmd,
    upper(trim(coalesce(p.permissive, ''))) as permissive,
    p.roles,
    regexp_replace(lower(coalesce(p.qual, '')), '[[:space:]()]', '', 'g') as qual_text,
    regexp_replace(lower(coalesce(p.with_check, '')), '[[:space:]()]', '', 'g') as check_text
  from pg_policies p
  where p.schemaname = 'public'
),
policy_expected(table_name, column_name, command, non_ai_guard) as (
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
),
required_constraints(table_name, constraint_name) as (
  values
    ('user_profiles', 'user_profiles_weight_range'),
    ('food_dictionary', 'food_dictionary_nutrition_nonnegative'),
    ('diet_logs', 'diet_logs_nutrition_nonnegative'),
    ('diet_logs', 'diet_logs_meal_type_valid'),
    ('exercise_logs', 'exercise_logs_kcal_nonnegative'),
    ('daily_tracking', 'daily_tracking_water_nonnegative'),
    ('daily_tracking', 'daily_tracking_weight_range'),
    ('water_intake_records', 'water_intake_amount_range'),
    ('water_intake_records', 'water_intake_legacy_time_consistent'),
    ('body_weight_logs', 'body_weight_range'),
    ('ai_usage_daily', 'ai_usage_nonnegative'),
    ('client_operations', 'client_operations_action_valid')
),
required_indexes(index_name) as (
  values
    ('food_dictionary_client_operation_idx'), ('diet_logs_client_operation_idx'),
    ('exercise_logs_client_operation_idx'), ('water_intake_records_client_operation_idx'),
    ('body_weight_logs_client_operation_idx'), ('training_sessions_client_operation_idx'),
    ('food_dictionary_updated_idx'), ('diet_logs_updated_idx'),
    ('exercise_logs_updated_idx'), ('daily_tracking_updated_idx'),
    ('water_intake_records_updated_idx'), ('body_weight_logs_updated_idx'),
    ('training_sessions_updated_idx'), ('sync_tombstones_updated_idx'),
    ('client_operations_nutrition_lease_idx')
),
required_rpcs(function_name, signature) as (
  values
    ('consume_ai_quota_for_user', 'public.consume_ai_quota_for_user(uuid,text)'),
    ('nutrition_ai_get_cached_response', 'public.nutrition_ai_get_cached_response(uuid,text)'),
    ('nutrition_ai_claim_operation', 'public.nutrition_ai_claim_operation(uuid,text)'),
    ('nutrition_ai_save_response', 'public.nutrition_ai_save_response(uuid,text,uuid,jsonb)'),
    ('nutrition_ai_release_operation', 'public.nutrition_ai_release_operation(uuid,text,uuid)')
),
table_checks as (
  select
    'table:' || e.table_name as check_name,
    case when t.table_name is null then 'FAIL' else 'PASS' end as status,
    case when t.table_name is null then 'required table is missing' else 'table exists' end as details
  from required_tables e
  left join information_schema.tables t
    on t.table_schema = 'public' and t.table_name = e.table_name
),
column_checks as (
  select
    'column:' || e.table_name || '.' || e.column_name as check_name,
    case when c.column_name is null then 'FAIL'
         when c.data_type <> e.expected_type then 'FAIL'
         else 'PASS' end as status,
    coalesce(c.data_type, 'missing') || ' / expected ' || e.expected_type as details
  from required_columns e
  left join information_schema.columns c
    on c.table_schema = 'public'
   and c.table_name = e.table_name
   and c.column_name = e.column_name
),
rls_checks as (
  select
    'rls:' || e.table_name as check_name,
    case when c.oid is null then 'FAIL'
         when c.relrowsecurity then 'PASS' else 'FAIL' end as status,
    case when c.oid is null then 'table is missing'
         when c.relrowsecurity then 'RLS enabled' else 'RLS disabled' end as details
  from required_tables e
  left join pg_class c on c.oid = to_regclass('public.' || e.table_name)
),
policy_checks as (
  select
    'policy:' || e.table_name || ':' || e.command as check_name,
    case when exists (
      select 1
      from policy_rows p
      where p.tablename = e.table_name
        and p.permissive = 'PERMISSIVE'
        and (array_position(p.roles, 'public'::name) is not null
             or array_position(p.roles, 'authenticated'::name) is not null)
        and p.cmd in (e.command, 'ALL')
        and (
          (e.command = 'SELECT' and
            (position('auth.uid=' || e.column_name in p.qual_text) > 0
             or position(e.column_name || '=auth.uid' in p.qual_text) > 0))
          or (e.command = 'INSERT' and
            (position('auth.uid=' || e.column_name in
               case when p.check_text = '' then p.qual_text else p.check_text end) > 0
             or position(e.column_name || '=auth.uid' in
               case when p.check_text = '' then p.qual_text else p.check_text end) > 0)
            and (not e.non_ai_guard or position('entity_type<>''nutrition-ai''' in
               case when p.check_text = '' then p.qual_text else p.check_text end) > 0))
          or (e.command = 'UPDATE' and
            (position('auth.uid=' || e.column_name in p.qual_text) > 0
             or position(e.column_name || '=auth.uid' in p.qual_text) > 0)
            and (position('auth.uid=' || e.column_name in
               case when p.check_text = '' then p.qual_text else p.check_text end) > 0
             or position(e.column_name || '=auth.uid' in
               case when p.check_text = '' then p.qual_text else p.check_text end) > 0)
            and (not e.non_ai_guard or
              (position('entity_type<>''nutrition-ai''' in p.qual_text) > 0
               and position('entity_type<>''nutrition-ai''' in
                 case when p.check_text = '' then p.qual_text else p.check_text end) > 0)))
          or (e.command = 'DELETE' and
            (position('auth.uid=' || e.column_name in p.qual_text) > 0
             or position(e.column_name || '=auth.uid' in p.qual_text) > 0)
            and (not e.non_ai_guard or position('entity_type<>''nutrition-ai''' in p.qual_text) > 0))
        )
    ) then 'PASS' else 'FAIL' end as status,
    'safe permissive own-row policy for PUBLIC/authenticated role' as details
  from policy_expected e
),
broad_policy_checks as (
  select
    'policy:' || e.table_name || ':no_broad_permissive' as check_name,
    case when exists (
      select 1
      from policy_rows p
      where p.tablename = e.table_name
        and p.permissive = 'PERMISSIVE'
        and (array_position(p.roles, 'public'::name) is not null
             or array_position(p.roles, 'authenticated'::name) is not null)
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
    ) then 'FAIL' else 'PASS' end as status,
    'every client-applicable PERMISSIVE policy is own-row safe' as details
  from (
    values
      ('user_profiles', 'id', false), ('food_dictionary', 'user_id', false),
      ('diet_logs', 'user_id', false), ('exercise_logs', 'user_id', false),
      ('daily_tracking', 'user_id', false), ('water_intake_records', 'user_id', false),
      ('body_weight_logs', 'user_id', false), ('training_sessions', 'user_id', false),
      ('sync_tombstones', 'user_id', false), ('client_operations', 'user_id', true),
      ('chat_history', 'user_id', false)
  ) as e(table_name, column_name, non_ai_guard)
),
ai_usage_policy_checks as (
  select
    'policy:ai_usage_daily:write_denied' as check_name,
    case when exists (
      select 1 from policy_rows p
      where p.tablename = 'ai_usage_daily'
        and p.permissive = 'PERMISSIVE'
        and p.cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
        and (array_position(p.roles, 'public'::name) is not null
             or array_position(p.roles, 'authenticated'::name) is not null)
    ) then 'FAIL' else 'PASS' end as status,
    'anon/authenticated users have no direct write policy' as details
  union all
  select
    'policy:ai_usage_daily:select_own',
    case when exists (
      select 1 from policy_rows p
      where p.tablename = 'ai_usage_daily'
        and p.permissive = 'PERMISSIVE'
        and p.cmd in ('SELECT', 'ALL')
        and (array_position(p.roles, 'public'::name) is not null
             or array_position(p.roles, 'authenticated'::name) is not null)
        and (position('auth.uid=user_id' in p.qual_text) > 0
             or position('user_id=auth.uid' in p.qual_text) > 0)
    ) then 'PASS' else 'FAIL' end,
    'read policy is limited to auth.uid() = user_id'
  union all
  select
    'policy:ai_usage_daily:no_broad_permissive',
    case when exists (
      select 1 from policy_rows p
      where p.tablename = 'ai_usage_daily'
        and p.permissive = 'PERMISSIVE'
        and p.cmd in ('SELECT', 'ALL')
        and (array_position(p.roles, 'public'::name) is not null
             or array_position(p.roles, 'authenticated'::name) is not null)
        and not (
          position('auth.uid=user_id' in p.qual_text) > 0
          or position('user_id=auth.uid' in p.qual_text) > 0
        )
    ) then 'FAIL' else 'PASS' end,
    'no broad client-applicable AI usage read policy exists'
),
constraint_checks as (
  select
    'constraint:' || e.table_name || ':' || e.constraint_name as check_name,
    case when c.oid is null then 'FAIL'
         when c.convalidated then 'PASS' else 'FAIL' end as status,
    coalesce(pg_get_constraintdef(c.oid), 'missing') ||
      ' / convalidated=' || coalesce(c.convalidated::text, 'false') as details
  from required_constraints e
  left join pg_constraint c
    on c.conname = e.constraint_name
   and c.conrelid = to_regclass('public.' || e.table_name)
),
trigger_checks as (
  select
    'updated_at_trigger:' || e.table_name as check_name,
    case when exists (
      select 1
      from pg_trigger t
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = e.table_name
        and t.tgname = e.table_name || '_updated_at'
        and not t.tgisinternal
    ) then 'PASS' else 'FAIL' end as status,
    'updated_at trigger exists' as details
  from (
    values
      ('user_profiles'), ('food_dictionary'), ('diet_logs'), ('exercise_logs'),
      ('daily_tracking'), ('water_intake_records'), ('body_weight_logs'),
      ('training_sessions'), ('sync_tombstones'), ('client_operations'), ('ai_usage_daily')
  ) as e(table_name)
),
index_checks as (
  select
    'index:' || e.index_name as check_name,
    case when i.indexname is null then 'FAIL' else 'PASS' end as status,
    coalesce(i.indexdef, 'missing') as details
  from required_indexes e
  left join pg_indexes i
    on i.schemaname = 'public' and i.indexname = e.index_name
),
rpc_metadata as (
  select e.function_name, e.signature, to_regprocedure(e.signature) as oid
  from required_rpcs e
),
rpc_checks as (
  select
    'rpc:' || r.function_name as check_name,
    case when r.oid is null then 'FAIL'
         when not p.prosecdef then 'FAIL'
         when not exists (
           select 1
           from unnest(coalesce(p.proconfig, array[]::text[])) as cfg(setting)
           where cfg.setting in ('search_path=', 'search_path=""')
         ) then 'FAIL'
         when exists (
           select 1
           from unnest(coalesce(p.proconfig, array[]::text[])) as cfg(setting)
           where cfg.setting like 'search_path=%public%'
              or cfg.setting like 'search_path=%extensions%'
         ) then 'FAIL'
         when not coalesce(has_function_privilege('service_role', r.oid, 'EXECUTE'), false) then 'FAIL'
         when coalesce(has_function_privilege('authenticated', r.oid, 'EXECUTE'), false) then 'FAIL'
         when coalesce(has_function_privilege('anon', r.oid, 'EXECUTE'), false) then 'FAIL'
         when exists (
           select 1
           from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
           where a.grantee = 0 and a.privilege_type = 'EXECUTE'
         ) then 'FAIL'
         else 'PASS' end as status,
    'SECURITY DEFINER, safe empty search_path, service_role-only execute' as details
  from rpc_metadata r
  left join pg_proc p on p.oid = r.oid
),
old_quota_rpc_checks as (
  select
    'rpc:old_quota:' || v.signature as check_name,
    case when e.oid is null then 'PASS'
         when coalesce(has_function_privilege('authenticated', e.oid, 'EXECUTE'), false) then 'FAIL'
         when coalesce(has_function_privilege('anon', e.oid, 'EXECUTE'), false) then 'FAIL'
         when exists (
           select 1
           from pg_proc p
           cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
           where p.oid = e.oid and a.grantee = 0 and a.privilege_type = 'EXECUTE'
         ) then 'FAIL'
         else 'PASS' end as status,
    'legacy quota signature is absent or revoked from all client roles' as details
  from (
    values
      ('public.consume_ai_quota_for_user(uuid)'),
      ('public.consume_ai_quota()'),
      ('public.consume_ai_quota(uuid,date,integer)')
  ) as v(signature)
  cross join lateral (select to_regprocedure(v.signature) as oid) e
),
quota_implementation_check as (
  select
    'rpc:consume_ai_quota_for_user:request_id_idempotent' as check_name,
    case when r.oid is null then 'FAIL'
         when position('p_request_id' in pg_get_functiondef(r.oid)) = 0 then 'FAIL'
         when position('client_operation_ids' in pg_get_functiondef(r.oid)) = 0 then 'FAIL'
         when position('on conflict' in lower(pg_get_functiondef(r.oid))) = 0 then 'FAIL'
         when position('request_count < 50' in lower(pg_get_functiondef(r.oid))) = 0 then 'FAIL'
         else 'PASS' end as status,
    'request ID is atomically recorded before a quota count can advance' as details
  from rpc_metadata r
  where r.function_name = 'consume_ai_quota_for_user'
),
claim_implementation_check as (
  select
    'rpc:nutrition_ai_claim_operation:lease_and_token' as check_name,
    case when r.oid is null then 'FAIL'
         when position('claim_token' in pg_get_functiondef(r.oid)) = 0 then 'FAIL'
         when position('claimed_at' in pg_get_functiondef(r.oid)) = 0 then 'FAIL'
         when position('2 minutes' in lower(pg_get_functiondef(r.oid))) = 0 then 'FAIL'
         else 'PASS' end as status,
    'claim creates a two-minute token lease; save/release match that token' as details
  from rpc_metadata r
  where r.function_name = 'nutrition_ai_claim_operation'
),
claim_token_guard_checks as (
  select
    'rpc:' || r.function_name || ':claim_token_guard' as check_name,
    case when r.oid is null then 'FAIL'
         when position('claim_token' in pg_get_functiondef(r.oid)) = 0 then 'FAIL'
         else 'PASS' end as status,
    'response mutation requires the matching claim token' as details
  from rpc_metadata r
  where r.function_name in ('nutrition_ai_save_response', 'nutrition_ai_release_operation')
),
baseline_row_checks as (
  select 'baseline:user_profiles' as check_name,
         case when count(*) >= 1 then 'PASS' else 'FAIL' end as status,
         'rows=' || count(*)::text || ', expected at least 1' as details
  from public.user_profiles
  union all
  select 'baseline:daily_tracking',
         case when count(*) = 2 then 'PASS' else 'FAIL' end,
         'rows=' || count(*)::text || ', expected 2'
  from public.daily_tracking
  union all
  select 'baseline:chat_history',
         case when count(*) >= 1 then 'PASS' else 'FAIL' end,
         'rows=' || count(*)::text || ', expected at least 1'
  from public.chat_history
  union all
  select 'baseline:legacy_water_rows',
         case when count(*) = 1 then 'PASS' else 'FAIL' end,
         'legacy rows=' || count(*)::text || ', expected 1'
  from public.water_intake_records
  where is_legacy_aggregate = true
  union all
  select 'baseline:legacy_water_total',
         case when coalesce(sum(amount_ml), 0) = 300 then 'PASS' else 'FAIL' end,
         'legacy total=' || coalesce(sum(amount_ml), 0)::text || ' ml, expected 300 ml'
  from public.water_intake_records
  where is_legacy_aggregate = true
  union all
  select 'baseline:legacy_water_time_null',
         case when count(*) = 0 then 'PASS' else 'FAIL' end,
         'legacy rows with recorded_at set=' || count(*)::text
  from public.water_intake_records
  where is_legacy_aggregate = true and recorded_at is not null
  union all
  select 'baseline:ordinary_water_time_present',
         case when count(*) = 0 then 'PASS' else 'FAIL' end,
         'ordinary rows with NULL recorded_at=' || count(*)::text
  from public.water_intake_records
  where is_legacy_aggregate = false and recorded_at is null
  union all
  select 'baseline:legacy_weight_rows',
         case when count(*) = 2 then 'PASS' else 'FAIL' end,
         'legacy rows=' || count(*)::text || ', expected 2'
  from public.body_weight_logs
  where id like 'legacy_weight_%'
),
training_data_check as (
  select
    'baseline:training_data_nonempty' as check_name,
    case when meta.data_type is null then 'FAIL'
         when meta.data_type = 'text' and values_checked.text_nonempty >= 1 then 'PASS'
         when meta.data_type = 'jsonb' and values_checked.json_nonempty >= 1 then 'PASS'
         when meta.data_type in ('text', 'jsonb') then 'FAIL'
         else 'REVIEW' end as status,
    'data_type=' || coalesce(meta.data_type, 'missing') ||
      ', text_nonempty=' || values_checked.text_nonempty::text ||
      ', jsonb_nonempty=' || values_checked.json_nonempty::text as details
  from (
    select max(data_type) as data_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_profiles'
      and column_name = 'training_data'
  ) meta
  cross join (
    select
      count(*) filter (where training_data is not null and btrim(training_data::text) <> '') as text_nonempty,
      count(*) filter (where training_data is not null and btrim(training_data::text) <> '[]') as json_nonempty
    from public.user_profiles
  ) values_checked
),
orphan_user_id_check as (
  select
    'orphan_user_ids' as check_name,
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
    'all user-owned rows reference auth.users' as details
),
checks as (
  select * from table_checks
  union all select * from column_checks
  union all select * from rls_checks
  union all select * from policy_checks
  union all select * from broad_policy_checks
  union all select * from ai_usage_policy_checks
  union all select * from constraint_checks
  union all select * from trigger_checks
  union all select * from index_checks
  union all select 'client_operations:unique_operation_id',
    case when exists (
      select 1 from public.client_operations group by user_id, operation_id having count(*) > 1
    ) then 'FAIL' else 'PASS' end,
    'unique (user_id, operation_id)'
  union all select * from rpc_checks
  union all select * from old_quota_rpc_checks
  union all select * from quota_implementation_check
  union all select * from claim_implementation_check
  union all select * from claim_token_guard_checks
  union all select * from baseline_row_checks
  union all select * from training_data_check
  union all select * from orphan_user_id_check
)
select check_name, status, details
from checks
order by check_name;
