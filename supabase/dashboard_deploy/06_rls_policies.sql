/*
Purpose: Enable RLS and minimally add missing policies based on actual expressions.
Read-only: No.
Data modification: RLS metadata only; existing policies are never dropped or replaced.
Expected time: Under 30 seconds.
Success: Existing safe own-row policies remain; only missing protections are added.
Failure/retry: Safe to rerun. Unsafe or conflicting policies stop execution for review.
*/

begin;

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
  with policy_text as (
    select p.cmd,
      regexp_replace(lower(coalesce(p.qual, '')), '[[:space:]()]', '', 'g') as qual_text,
      regexp_replace(lower(coalesce(p.with_check, '')), '[[:space:]()]', '', 'g') as check_text
    from pg_policies p
    where p.schemaname = 'public'
      and p.tablename = p_table_name
      and p.permissive = true
  )
  select exists (
    select 1
    from policy_text p
    where p.cmd in (upper(p_command), '*')
      and (
        (
          p_command = 'SELECT'
          and (
            position('auth.uid=' || lower(p_column_name) in p.qual_text) > 0
            or position(lower(p_column_name) || '=auth.uid' in p.qual_text) > 0
          )
        )
        or (
          p_command = 'INSERT'
          and (position('auth.uid=' || lower(p_column_name) in p.check_text) > 0
               or position(lower(p_column_name) || '=auth.uid' in p.check_text) > 0)
          and (not p_non_ai_guard or position('entity_type<>''nutrition-ai''' in p.check_text) > 0)
        )
        or (
          p_command = 'UPDATE'
          and (position('auth.uid=' || lower(p_column_name) in p.qual_text) > 0
               or position(lower(p_column_name) || '=auth.uid' in p.qual_text) > 0)
          and (position('auth.uid=' || lower(p_column_name) in p.check_text) > 0
               or position(lower(p_column_name) || '=auth.uid' in p.check_text) > 0)
          and (not p_non_ai_guard
               or (position('entity_type<>''nutrition-ai''' in p.qual_text) > 0
                   and position('entity_type<>''nutrition-ai''' in p.check_text) > 0))
        )
        or (
          p_command = 'DELETE'
          and (position('auth.uid=' || lower(p_column_name) in p.qual_text) > 0
               or position(lower(p_column_name) || '=auth.uid' in p.qual_text) > 0)
          and (not p_non_ai_guard or position('entity_type<>''nutrition-ai''' in p.qual_text) > 0)
        )
      )
  );
$$;

-- Stop before changing metadata if an existing permissive policy would broaden
-- access beyond the required own-row rule. Existing restrictive policies remain.
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
    if table_name = 'user_profiles' then
      column_name := 'id';
    else
      column_name := 'user_id';
    end if;

    if to_regclass('public.' || table_name) is null then
      continue;
    end if;

    if table_name = 'ai_usage_daily' then
      if exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = table_name
          and (cmd in ('INSERT', 'UPDATE', 'DELETE', '*'))
      ) then
        raise exception 'POLICY_REVIEW_REQUIRED: ai_usage_daily has a write policy';
      end if;
      if exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = table_name
          and permissive = true and cmd in ('SELECT', '*')
          and not public.goat_policy_is_safe(table_name, 'SELECT', column_name, false)
      ) then
        raise exception 'POLICY_REVIEW_REQUIRED: ai_usage_daily has an unsafe read policy';
      end if;
      continue;
    end if;

    has_unsafe :=
        (exists (select 1 from pg_policies where schemaname = 'public'
          and tablename = table_name and permissive = true and cmd in ('SELECT', '*')
          and not public.goat_policy_is_safe(table_name, 'SELECT', column_name,
              table_name = 'client_operations'))) or
        (exists (select 1 from pg_policies where schemaname = 'public'
          and tablename = table_name and permissive = true and cmd in ('INSERT', '*')
          and not public.goat_policy_is_safe(table_name, 'INSERT', column_name,
              table_name = 'client_operations'))) or
        (exists (select 1 from pg_policies where schemaname = 'public'
          and tablename = table_name and permissive = true and cmd in ('UPDATE', '*')
          and not public.goat_policy_is_safe(table_name, 'UPDATE', column_name,
              table_name = 'client_operations'))) or
        (exists (select 1 from pg_policies where schemaname = 'public'
          and tablename = table_name and permissive = true and cmd in ('DELETE', '*')
          and not public.goat_policy_is_safe(table_name, 'DELETE', column_name,
              table_name = 'client_operations')));
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

-- Existing tables: create only a missing actual protection, regardless of its name.
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
      execute format(
        'create policy goat_dashboard_select_own on public.%I for select using (auth.uid() = %I)',
        table_name, column_name
      );
    end if;
    if not public.goat_policy_is_safe(table_name, 'INSERT', column_name, non_ai) then
      execute format(
        'create policy goat_dashboard_insert_own on public.%I for insert with check (auth.uid() = %I%s)',
        table_name, column_name,
        case when non_ai then ' and entity_type <> ''nutrition-ai''' else '' end
      );
    end if;
    if not public.goat_policy_is_safe(table_name, 'UPDATE', column_name, non_ai) then
      execute format(
        'create policy goat_dashboard_update_own on public.%I for update using (auth.uid() = %I%s) with check (auth.uid() = %I%s)',
        table_name, column_name,
        case when non_ai then ' and entity_type <> ''nutrition-ai''' else '' end,
        column_name,
        case when non_ai then ' and entity_type <> ''nutrition-ai''' else '' end
      );
    end if;
    if not public.goat_policy_is_safe(table_name, 'DELETE', column_name, non_ai) then
      execute format(
        'create policy goat_dashboard_delete_own on public.%I for delete using (auth.uid() = %I%s)',
        table_name, column_name,
        case when non_ai then ' and entity_type <> ''nutrition-ai''' else '' end
      );
    end if;
  end loop;
end $$;

-- ai_usage_daily intentionally has no ordinary INSERT/UPDATE/DELETE policy.
-- Its writes are exclusively through SECURITY DEFINER RPC.

-- A user may inspect only their own quota usage. This is the only policy
-- created for ai_usage_daily; all write access remains RPC-only.
do $$
begin
  if to_regclass('public.ai_usage_daily') is not null
     and not public.goat_policy_is_safe('ai_usage_daily', 'SELECT', 'user_id', false) then
    create policy goat_dashboard_ai_usage_select_own
      on public.ai_usage_daily for select using (auth.uid() = user_id);
  end if;
end $$;

revoke all on function public.goat_policy_is_safe(text, text, text, boolean) from public;

commit;
