/*
Purpose: Enable RLS and minimally add missing policies based on actual expressions.
Read-only: No.
Data modification: RLS metadata only; existing policies are never dropped or replaced.
Expected time: Under 30 seconds.
Success: Existing safe own-row policies, including ALL policies, remain unchanged.
Failure/retry: Safe to rerun. Unsafe or conflicting policies stop for review.
*/

begin;

-- pg_policies.permissive is text in the production catalog. ALL is the only
-- command-wide policy value accepted here; ALL applies to every CRUD command.
create or replace function public.goat_policy_is_safe(
  p_table_name text,
  p_command text,
  p_column_name text,
  p_non_ai_guard boolean default false
)
returns boolean
language sql
stable
as $$
  with base as (
    select upper(trim(coalesce(p.cmd, ''))) as cmd,
      upper(trim(coalesce(p.permissive, ''))) as permissive,
      p.roles,
      regexp_replace(lower(coalesce(p.qual, '')), '[[:space:]()]', '', 'g') as qual_text,
      regexp_replace(lower(coalesce(p.with_check, '')), '[[:space:]()]', '', 'g') as check_text
    from pg_policies p
    where p.schemaname = 'public' and p.tablename = p_table_name
  ), policy_text as (
    select cmd, permissive, roles, qual_text,
      case when check_text = '' then qual_text else check_text end as effective_check
    from base
  )
  select exists (
    select 1 from policy_text p
    where p.permissive = 'PERMISSIVE'
      and (array_position(p.roles, 'public'::name) is not null
           or array_position(p.roles, 'authenticated'::name) is not null)
      and p.cmd in (upper(p_command), 'ALL')
      and (
        (p_command = 'SELECT' and
          (position('auth.uid=' || lower(p_column_name) in p.qual_text) > 0
           or position(lower(p_column_name) || '=auth.uid' in p.qual_text) > 0))
        or (p_command = 'INSERT' and
          (position('auth.uid=' || lower(p_column_name) in p.effective_check) > 0
           or position(lower(p_column_name) || '=auth.uid' in p.effective_check) > 0)
          and (not p_non_ai_guard or position('entity_type<>''nutrition-ai''' in p.effective_check) > 0))
        or (p_command = 'UPDATE' and
          (position('auth.uid=' || lower(p_column_name) in p.qual_text) > 0
           or position(lower(p_column_name) || '=auth.uid' in p.qual_text) > 0)
          and (position('auth.uid=' || lower(p_column_name) in p.effective_check) > 0
           or position(lower(p_column_name) || '=auth.uid' in p.effective_check) > 0)
          and (not p_non_ai_guard or
            (position('entity_type<>''nutrition-ai''' in p.qual_text) > 0
             and position('entity_type<>''nutrition-ai''' in p.effective_check) > 0)))
        or (p_command = 'DELETE' and
          (position('auth.uid=' || lower(p_column_name) in p.qual_text) > 0
           or position(lower(p_column_name) || '=auth.uid' in p.qual_text) > 0)
          and (not p_non_ai_guard or position('entity_type<>''nutrition-ai''' in p.qual_text) > 0))
      )
  );
$$;

-- Every applicable permissive policy is checked individually. A safe policy
-- does not mask another broad policy on the same table.
do $$
declare
  table_name text;
  column_name text;
  has_unsafe boolean;
begin
  foreach table_name in array array[
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations',
    'ai_usage_daily', 'chat_history'
  ] loop
    column_name := case when table_name = 'user_profiles' then 'id' else 'user_id' end;
    if to_regclass('public.' || table_name) is null then
      continue;
    end if;

    if table_name = 'ai_usage_daily' then
      if exists (
        select 1 from pg_policies p
        where p.schemaname = 'public' and p.tablename = table_name
          and upper(trim(coalesce(p.permissive, ''))) = 'PERMISSIVE'
          and (array_position(p.roles, 'public'::name) is not null
               or array_position(p.roles, 'authenticated'::name) is not null)
          and upper(trim(coalesce(p.cmd, ''))) in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
      ) then
        raise exception 'POLICY_REVIEW_REQUIRED: ai_usage_daily has a permissive write policy';
      end if;
      if exists (
        select 1 from pg_policies p
        where p.schemaname = 'public' and p.tablename = table_name
          and upper(trim(coalesce(p.permissive, ''))) = 'PERMISSIVE'
          and (array_position(p.roles, 'public'::name) is not null
               or array_position(p.roles, 'authenticated'::name) is not null)
          and upper(trim(coalesce(p.cmd, ''))) in ('SELECT', 'ALL')
          and not (
            position('auth.uid=' || column_name in
              regexp_replace(lower(coalesce(p.qual, '')), '[[:space:]()]', '', 'g')) > 0
            or position(column_name || '=auth.uid' in
              regexp_replace(lower(coalesce(p.qual, '')), '[[:space:]()]', '', 'g')) > 0
          )
      ) then
        raise exception 'POLICY_REVIEW_REQUIRED: ai_usage_daily has an unsafe permissive read policy';
      end if;
      continue;
    end if;

    has_unsafe := exists (
      select 1 from (
        select upper(trim(coalesce(p.cmd, ''))) as cmd,
          upper(trim(coalesce(p.permissive, ''))) as permissive,
          p.roles,
          regexp_replace(lower(coalesce(p.qual, '')), '[[:space:]()]', '', 'g') as qual_text,
          regexp_replace(lower(coalesce(p.with_check, '')), '[[:space:]()]', '', 'g') as check_text
        from pg_policies p
        where p.schemaname = 'public' and p.tablename = table_name
      ) p
      where p.permissive = 'PERMISSIVE'
        and (array_position(p.roles, 'public'::name) is not null
             or array_position(p.roles, 'authenticated'::name) is not null)
        and (
          (p.cmd in ('SELECT', 'ALL') and not (
            position('auth.uid=' || column_name in p.qual_text) > 0
            or position(column_name || '=auth.uid' in p.qual_text) > 0
          ))
          or (p.cmd in ('INSERT', 'ALL') and not (
            (position('auth.uid=' || column_name in
              case when p.check_text = '' then p.qual_text else p.check_text end) > 0
             or position(column_name || '=auth.uid' in
              case when p.check_text = '' then p.qual_text else p.check_text end) > 0)
            and (table_name <> 'client_operations' or
              position('entity_type<>''nutrition-ai''' in
                case when p.check_text = '' then p.qual_text else p.check_text end) > 0)
          ))
          or (p.cmd in ('UPDATE', 'ALL') and not (
            (position('auth.uid=' || column_name in p.qual_text) > 0
             or position(column_name || '=auth.uid' in p.qual_text) > 0)
            and (position('auth.uid=' || column_name in
              case when p.check_text = '' then p.qual_text else p.check_text end) > 0
             or position(column_name || '=auth.uid' in
              case when p.check_text = '' then p.qual_text else p.check_text end) > 0)
            and (table_name <> 'client_operations' or
              (position('entity_type<>''nutrition-ai''' in p.qual_text) > 0
               and position('entity_type<>''nutrition-ai''' in
                 case when p.check_text = '' then p.qual_text else p.check_text end) > 0))
          ))
          or (p.cmd in ('DELETE', 'ALL') and not (
            (position('auth.uid=' || column_name in p.qual_text) > 0
             or position(column_name || '=auth.uid' in p.qual_text) > 0)
            and (table_name <> 'client_operations' or
              position('entity_type<>''nutrition-ai''' in p.qual_text) > 0)
          ))
        )
    );
    if has_unsafe then
      raise exception 'POLICY_REVIEW_REQUIRED: unsafe permissive policy on %', table_name;
    end if;
  end loop;
end $$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'food_dictionary', 'diet_logs', 'exercise_logs', 'daily_tracking',
    'water_intake_records', 'body_weight_logs', 'training_sessions',
    'sync_tombstones', 'client_operations', 'chat_history'
  ] loop
    if to_regclass('public.' || table_name) is not null then
      execute format('alter table public.%I enable row level security', table_name);
    end if;
  end loop;
end $$;

alter table public.user_profiles enable row level security;
alter table public.ai_usage_daily enable row level security;

-- Only missing actual protections are added. A safe ALL policy satisfies each
-- command and therefore prevents duplicate SELECT/INSERT/UPDATE/DELETE policies.
do $$
declare
  table_name text;
  column_name text;
  non_ai boolean;
begin
  foreach table_name in array array[
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations', 'chat_history'
  ] loop
    if to_regclass('public.' || table_name) is null then
      continue;
    end if;
    column_name := case when table_name = 'user_profiles' then 'id' else 'user_id' end;
    non_ai := table_name = 'client_operations';

    if not public.goat_policy_is_safe(table_name, 'SELECT', column_name, false) then
      execute format('create policy goat_dashboard_select_own on public.%I for select to authenticated using (auth.uid() = %I)', table_name, column_name);
    end if;
    if not public.goat_policy_is_safe(table_name, 'INSERT', column_name, non_ai) then
      execute format('create policy goat_dashboard_insert_own on public.%I for insert to authenticated with check (auth.uid() = %I%s)',
        table_name, column_name,
        case when non_ai then ' and entity_type <> ''nutrition-ai''' else '' end);
    end if;
    if not public.goat_policy_is_safe(table_name, 'UPDATE', column_name, non_ai) then
      execute format('create policy goat_dashboard_update_own on public.%I for update to authenticated using (auth.uid() = %I%s) with check (auth.uid() = %I%s)',
        table_name, column_name,
        case when non_ai then ' and entity_type <> ''nutrition-ai''' else '' end,
        column_name,
        case when non_ai then ' and entity_type <> ''nutrition-ai''' else '' end);
    end if;
    if not public.goat_policy_is_safe(table_name, 'DELETE', column_name, non_ai) then
      execute format('create policy goat_dashboard_delete_own on public.%I for delete to authenticated using (auth.uid() = %I%s)',
        table_name, column_name,
        case when non_ai then ' and entity_type <> ''nutrition-ai''' else '' end);
    end if;
  end loop;
end $$;

-- ai_usage_daily has no ordinary write policy. Reads are own-row only.
do $$
begin
  if not public.goat_policy_is_safe('ai_usage_daily', 'SELECT', 'user_id', false) then
    create policy goat_dashboard_ai_usage_select_own
      on public.ai_usage_daily for select to authenticated using (auth.uid() = user_id);
  end if;
end $$;

revoke all on function public.goat_policy_is_safe(text, text, text, boolean) from public;

commit;
