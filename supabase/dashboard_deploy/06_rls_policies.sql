/*
Purpose: Enable row-level security and add least-privilege per-user policies.
Read-only: No.
Data modification: Changes RLS metadata only; no business rows are changed.
Expected time: Under 30 seconds.
Success: Every target table has RLS enabled and four own-row policies.
Failure/retry: Safe to rerun. Existing policies are never dropped; name conflicts require review.
*/

begin;

-- Never silently coexist with an unknown policy. Run 01, review the policy
-- listing, and handle any manual conflict before retrying this file.
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename in (
        'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
        'daily_tracking', 'water_intake_records', 'body_weight_logs',
        'training_sessions', 'sync_tombstones', 'client_operations',
        'ai_usage_daily', 'chat_history'
      )
      and policyname not like 'goat_%'
  ) then
    raise exception 'POLICY_REVIEW_REQUIRED: unknown existing policy found; stop and review 01 output';
  end if;
end $$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'food_dictionary', 'diet_logs', 'exercise_logs', 'daily_tracking',
    'water_intake_records', 'body_weight_logs', 'training_sessions',
    'sync_tombstones', 'client_operations', 'ai_usage_daily'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = table_name
        and policyname = 'goat_select_own'
    ) then
      execute format(
        'create policy goat_select_own on public.%I for select using (auth.uid() = user_id)',
        table_name
      );
    end if;
    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = table_name
        and policyname = 'goat_insert_own'
    ) then
      execute format(
        'create policy goat_insert_own on public.%I for insert with check (auth.uid() = user_id)',
        table_name
      );
    end if;
    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = table_name
        and policyname = 'goat_update_own'
    ) then
      execute format(
        'create policy goat_update_own on public.%I for update using (auth.uid() = user_id) with check (auth.uid() = user_id)',
        table_name
      );
    end if;
    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = table_name
        and policyname = 'goat_delete_own'
    ) then
      execute format(
        'create policy goat_delete_own on public.%I for delete using (auth.uid() = user_id)',
        table_name
      );
    end if;
  end loop;
end $$;

alter table public.user_profiles enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public'
      and tablename = 'user_profiles' and policyname = 'goat_profile_select_own') then
    create policy goat_profile_select_own on public.user_profiles
      for select using (auth.uid() = id);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public'
      and tablename = 'user_profiles' and policyname = 'goat_profile_insert_own') then
    create policy goat_profile_insert_own on public.user_profiles
      for insert with check (auth.uid() = id);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public'
      and tablename = 'user_profiles' and policyname = 'goat_profile_update_own') then
    create policy goat_profile_update_own on public.user_profiles
      for update using (auth.uid() = id) with check (auth.uid() = id);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public'
      and tablename = 'user_profiles' and policyname = 'goat_profile_delete_own') then
    create policy goat_profile_delete_own on public.user_profiles
      for delete using (auth.uid() = id);
  end if;
end $$;

do $$
begin
  if to_regclass('public.chat_history') is not null then
    alter table public.chat_history enable row level security;
    if not exists (select 1 from pg_policies where schemaname = 'public'
        and tablename = 'chat_history' and policyname = 'goat_chat_select_own') then
      create policy goat_chat_select_own on public.chat_history
        for select using (auth.uid() = user_id);
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public'
        and tablename = 'chat_history' and policyname = 'goat_chat_insert_own') then
      create policy goat_chat_insert_own on public.chat_history
        for insert with check (auth.uid() = user_id);
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public'
        and tablename = 'chat_history' and policyname = 'goat_chat_update_own') then
      create policy goat_chat_update_own on public.chat_history
        for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public'
        and tablename = 'chat_history' and policyname = 'goat_chat_delete_own') then
      create policy goat_chat_delete_own on public.chat_history
        for delete using (auth.uid() = user_id);
    end if;
  end if;
end $$;

commit;
