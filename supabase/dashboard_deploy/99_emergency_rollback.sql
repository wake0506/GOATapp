/*
Purpose: Reference-only rollback for metadata introduced by this deployment package.
Read-only: No.
Data modification: Removes only explicitly named package policies, indexes, triggers,
constraints, helper functions and AI RPCs after manual approval.
Expected time: Under 30 seconds when individually approved.
Success: Only confirmed package metadata is removed; all business rows remain.
Failure/retry: Stop immediately and restore from the confirmed backup if metadata ownership is unclear.

WARNING: Do not run this file as a routine step. Existing safe policies with other
names are intentionally untouched. This file contains no executable table or row removal.
*/

begin;

-- These goat_dashboard_* policies are package names. Confirm they were created by
-- 06 in the deployment record before running this rollback.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations',
    'chat_history'
  ] loop
    if to_regclass('public.' || table_name) is not null then
      execute format('drop policy if exists goat_dashboard_select_own on public.%I', table_name);
      execute format('drop policy if exists goat_dashboard_insert_own on public.%I', table_name);
      execute format('drop policy if exists goat_dashboard_update_own on public.%I', table_name);
      execute format('drop policy if exists goat_dashboard_delete_own on public.%I', table_name);
    end if;
  end loop;
  if to_regclass('public.ai_usage_daily') is not null then
    drop policy if exists goat_dashboard_ai_usage_select_own on public.ai_usage_daily;
  end if;
end $$;

-- Trigger names introduced by 05.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations', 'ai_usage_daily'
  ] loop
    if to_regclass('public.' || table_name) is not null then
      execute format('drop trigger if exists %I on public.%I', table_name || '_updated_at', table_name);
    end if;
  end loop;
end $$;

drop index if exists public.food_dictionary_client_operation_idx;
drop index if exists public.diet_logs_client_operation_idx;
drop index if exists public.exercise_logs_client_operation_idx;
drop index if exists public.water_intake_records_client_operation_idx;
drop index if exists public.body_weight_logs_client_operation_idx;
drop index if exists public.training_sessions_client_operation_idx;
drop index if exists public.food_dictionary_updated_idx;
drop index if exists public.diet_logs_updated_idx;
drop index if exists public.exercise_logs_updated_idx;
drop index if exists public.daily_tracking_updated_idx;
drop index if exists public.water_intake_records_updated_idx;
drop index if exists public.body_weight_logs_updated_idx;
drop index if exists public.training_sessions_updated_idx;
drop index if exists public.sync_tombstones_updated_idx;

-- Constraints introduced by 05. These statements remove metadata only; they do
-- not delete or rewrite rows. Confirm names and ownership before execution.
do $$
declare
  item record;
begin
  for item in select * from (values
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
  ) as v(table_name, constraint_name) loop
    if to_regclass('public.' || item.table_name) is not null then
      execute format('alter table public.%I drop constraint if exists %I',
        item.table_name, item.constraint_name);
    end if;
  end loop;
end $$;

-- RPCs and helper functions introduced or replaced by this package. Do not drop
-- the legacy parameterized consume_ai_quota overload; 07 only revokes its execute
-- privileges so old schema objects remain available for manual review.
drop function if exists public.nutrition_ai_get_cached_response(text);
drop function if exists public.nutrition_ai_claim_operation(text);
drop function if exists public.nutrition_ai_save_response(text, jsonb);
drop function if exists public.nutrition_ai_release_operation(text);
drop function if exists public.consume_ai_quota();
drop function if exists public.goat_policy_is_safe(text, text, text, boolean);
drop function if exists public.goat_set_updated_at();
drop function if exists public.goat_add_check_if_missing(text, text, text);
drop function if exists public.goat_assert_constraint_clean(text, text, text);
drop function if exists public.goat_validate_constraint_if_needed(text, text);

-- No executable business-data removal is present here. Old tables, old columns,
-- migrated water/weight rows, auth.users and user profiles must remain intact.

commit;
