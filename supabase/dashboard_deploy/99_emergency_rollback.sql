/*
Purpose: Reference-only rollback for objects introduced by this deployment package.
Read-only: No.
Data modification: The active statements below remove only named package metadata.
Expected time: Under 30 seconds when individually approved.
Success: Only explicitly named package objects are removed.
Failure/retry: Stop immediately; restore from the confirmed backup if data is involved.

WARNING: Do not run this file as a routine step. Confirm the project, backup and
rollback owner first. Old tables, old columns, auth.users and migrated business
data must never be removed by this file.
*/

begin;

-- Named policies introduced by 06. Review for manual policy conflicts first.
drop policy if exists goat_profile_select_own on public.user_profiles;
drop policy if exists goat_profile_insert_own on public.user_profiles;
drop policy if exists goat_profile_update_own on public.user_profiles;
drop policy if exists goat_profile_delete_own on public.user_profiles;

-- New trigger names introduced by 05. Do not remove unrelated triggers.
drop trigger if exists user_profiles_updated_at on public.user_profiles;
drop trigger if exists food_dictionary_updated_at on public.food_dictionary;
drop trigger if exists diet_logs_updated_at on public.diet_logs;
drop trigger if exists exercise_logs_updated_at on public.exercise_logs;
drop trigger if exists daily_tracking_updated_at on public.daily_tracking;
drop trigger if exists water_intake_records_updated_at on public.water_intake_records;
drop trigger if exists body_weight_logs_updated_at on public.body_weight_logs;
drop trigger if exists training_sessions_updated_at on public.training_sessions;
drop trigger if exists sync_tombstones_updated_at on public.sync_tombstones;
drop trigger if exists client_operations_updated_at on public.client_operations;
drop trigger if exists ai_usage_daily_updated_at on public.ai_usage_daily;

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

revoke all on function public.consume_ai_quota(uuid, date, integer) from public;
revoke all on function public.delete_user() from public;

-- The following data-bearing object removals are intentionally commented out.
-- Never remove old tables, old columns, migrated rows, auth.users, or user data.
-- drop table public.ai_usage_daily;
-- drop table public.client_operations;
-- drop table public.sync_tombstones;
-- drop table public.training_sessions;
-- drop table public.body_weight_logs;
-- drop table public.water_intake_records;

commit;
