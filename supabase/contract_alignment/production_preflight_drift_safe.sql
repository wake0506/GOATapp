-- Read-only production drift preflight. Never applies SQL or data changes.
-- EXPECTED_DRIFT is emitted only for the reviewed compatibility baseline.

with
expected_baseline(table_name) as (
  values
    ('user_profiles'), ('food_dictionary'), ('diet_logs'), ('exercise_logs'),
    ('daily_tracking'), ('water_intake_records'), ('body_weight_logs'),
    ('training_sessions'), ('client_operations'), ('ai_usage_daily'), ('chat_history')
),
checks as (
  select
    'baseline_tables'::text as check_name,
    case when count(*) = count(*) filter (where to_regclass('public.' || table_name) is not null)
      then 'PASS' else 'FAIL' end as status,
    format('present=%s/%s; missing=%s',
      count(*) filter (where to_regclass('public.' || table_name) is not null),
      count(*),
      coalesce(string_agg(table_name, ', ' order by table_name) filter (where to_regclass('public.' || table_name) is null), 'none')) as details
  from expected_baseline
  union all
  select
    'stage3c_tables'::text,
    case
      when to_regclass('public.sync_diagnostics') is not null
       and to_regclass('public.app_feature_flags') is not null then 'PASS'
      when to_regclass('public.sync_diagnostics') is null
       and to_regclass('public.app_feature_flags') is null then 'EXPECTED_DRIFT'
      else 'FAIL'
    end,
    format('sync_diagnostics=%s; app_feature_flags=%s',
      case when to_regclass('public.sync_diagnostics') is null then 'missing' else 'present' end,
      case when to_regclass('public.app_feature_flags') is null then 'missing' else 'present' end)
  union all
  select
    'contract_alignment_tables'::text,
    case
      when to_regclass('public.training_templates') is not null
       and to_regclass('public.ai_memories') is not null
       and to_regclass('public.ai_suggestions') is not null
       and to_regclass('public.ai_suggestion_feedback') is not null then 'PASS'
      when to_regclass('public.training_templates') is null
       and to_regclass('public.ai_memories') is null
       and to_regclass('public.ai_suggestions') is null
       and to_regclass('public.ai_suggestion_feedback') is null then 'EXPECTED_DRIFT'
      else 'FAIL'
    end,
    format('training_templates=%s; ai_memories=%s; ai_suggestions=%s; ai_suggestion_feedback=%s',
      case when to_regclass('public.training_templates') is null then 'missing' else 'present' end,
      case when to_regclass('public.ai_memories') is null then 'missing' else 'present' end,
      case when to_regclass('public.ai_suggestions') is null then 'missing' else 'present' end,
      case when to_regclass('public.ai_suggestion_feedback') is null then 'missing' else 'present' end)
  union all
  select
    'chat_history_columns'::text,
    case when exists (select 1 from pg_attribute where attrelid = to_regclass('public.chat_history') and attname = 'user_id' and not attisdropped)
           and exists (select 1 from pg_attribute where attrelid = to_regclass('public.chat_history') and attname = 'messages' and not attisdropped)
         then 'PASS' else 'FAIL' end,
    coalesce((select string_agg(format('%s %s%s', a.attname, format_type(a.atttypid, a.atttypmod), case when a.attnotnull then ' NOT NULL' else '' end), ', ' order by a.attnum)
      from pg_attribute a where a.attrelid = to_regclass('public.chat_history') and a.attnum > 0 and not a.attisdropped), 'table missing')
  union all
  select
    'chat_history_user_fk_cascade'::text,
    case when exists (
       select 1 from pg_constraint c
      where c.conrelid = to_regclass('public.chat_history')
        and c.contype = 'f'
        and c.confrelid = to_regclass('auth.users')
        and c.confdeltype = 'c'
        and exists (select 1 from pg_attribute a where a.attrelid = c.conrelid and a.attnum = any(c.conkey) and a.attname = 'user_id')
     ) then 'PASS'
     when not exists (
       select 1 from pg_constraint c
       where c.conrelid = to_regclass('public.chat_history')
         and c.contype = 'f'
     ) then 'EXPECTED_DRIFT'
     when exists (
       select 1 from pg_constraint c
       where c.conrelid = to_regclass('public.chat_history')
         and c.contype = 'f'
         and c.confrelid = to_regclass('auth.users')
         and c.confdeltype <> 'c'
         and exists (select 1 from pg_attribute a where a.attrelid = c.conrelid and a.attnum = any(c.conkey) and a.attname = 'user_id')
     ) then 'EXPECTED_DRIFT'
     else 'FAIL' end,
    'reviewed baseline permits no FK or an auth.users FK without CASCADE; unknown FK targets remain FAIL'
  union all
  select
    'chat_history_policy_surface'::text,
    case when not exists (
       select 1 from pg_policies p
      where p.schemaname = 'public' and p.tablename = 'chat_history'
        and ('public' = any(p.roles) or 'anon' = any(p.roles))
     ) and (select count(distinct p.cmd) from pg_policies p
      where p.schemaname = 'public' and p.tablename = 'chat_history'
        and p.roles = array['authenticated']::name[]
        and (coalesce(p.qual::text, '') like '%auth.uid()%'
          or coalesce(p.with_check::text, '') like '%auth.uid()%')) = 4
       then 'PASS'
     when (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = 'chat_history') = 1
       and exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = 'chat_history' and p.roles = array['public']::name[] and p.cmd = 'ALL')
       then 'EXPECTED_DRIFT'
     else 'FAIL' end,
    coalesce((select string_agg(format('%s roles=%s cmd=%s', policyname, roles::text, cmd), '; ' order by policyname) from pg_policies where schemaname = 'public' and tablename = 'chat_history'), 'no policies')
  union all
  select
    'versioned_sync'::text,
    case when to_regclass('public.app_feature_flags') is null then 'EXPECTED_DRIFT'
         else 'PASS' end,
    case when to_regclass('public.app_feature_flags') is null
       then 'feature flag table absent before compatibility migration'
       else 'feature flag table present; versioned_sync must be false' end
  union all
  select
    'migration_history'::text,
    case when to_regclass('supabase_migrations.schema_migrations') is null then 'EXPECTED_DRIFT' else 'PASS' end,
    case when to_regclass('supabase_migrations.schema_migrations') is null
       then 'managed migration history is not exposed to the read-only role; CLI must confirm exactly three reviewed versions pending'
      else 'migration history relation present; count requires a post-preflight read' end
)
select check_name, status, details from checks order by check_name;
