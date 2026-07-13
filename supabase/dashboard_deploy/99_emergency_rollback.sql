/*
Purpose: Human-reviewed rollback template for this deployment package.
Read-only: Yes until an operator explicitly uncommenting selected lines.
Data modification: None by default. Never remove tables, columns or business rows.
Expected time: Not applicable; this file is not an executable deployment step.
Success: Only individually approved package metadata is reverted.
Failure/retry: Stop and restore from the confirmed backup if ownership is unclear.

IMPORTANT: Every statement below is intentionally commented. Before using one,
confirm the deployment record shows that this exact object was created by this
package, confirm the backup and obtain explicit approval. Existing policies,
triggers, indexes, constraints and functions must not be removed just because
their names happen to match.
*/

-- begin;

-- Policies: uncomment one named policy only after confirming package ownership.
-- drop policy if exists goat_dashboard_select_own on public.<table_name>;
-- drop policy if exists goat_dashboard_insert_own on public.<table_name>;
-- drop policy if exists goat_dashboard_update_own on public.<table_name>;
-- drop policy if exists goat_dashboard_delete_own on public.<table_name>;
-- drop policy if exists goat_dashboard_ai_usage_select_own on public.ai_usage_daily;

-- Trigger metadata: confirm the exact table and trigger were created by 05.
-- drop trigger if exists <table_name>_updated_at on public.<table_name>;

-- Index metadata: confirm the exact index was created by 05.
-- drop index if exists public.food_dictionary_client_operation_idx;
-- drop index if exists public.diet_logs_client_operation_idx;
-- drop index if exists public.exercise_logs_client_operation_idx;
-- drop index if exists public.water_intake_records_client_operation_idx;
-- drop index if exists public.body_weight_logs_client_operation_idx;
-- drop index if exists public.training_sessions_client_operation_idx;
-- drop index if exists public.food_dictionary_updated_idx;
-- drop index if exists public.diet_logs_updated_idx;
-- drop index if exists public.exercise_logs_updated_idx;
-- drop index if exists public.daily_tracking_updated_idx;
-- drop index if exists public.water_intake_records_updated_idx;
-- drop index if exists public.body_weight_logs_updated_idx;
-- drop index if exists public.training_sessions_updated_idx;
-- drop index if exists public.sync_tombstones_updated_idx;
-- drop index if exists public.client_operations_nutrition_lease_idx;

-- Constraint metadata: never use these to hide invalid data; investigate first.
-- alter table public.<table_name> drop constraint if exists <constraint_name>;

-- RPC/helper metadata: only remove functions created by this package after review.
-- drop function if exists public.nutrition_ai_get_cached_response(text);
-- drop function if exists public.nutrition_ai_claim_operation(text);
-- drop function if exists public.nutrition_ai_save_response(text, jsonb);
-- drop function if exists public.nutrition_ai_release_operation(text);
-- drop function if exists public.consume_ai_quota();
-- drop function if exists public.goat_policy_is_safe(text, text, text, boolean);
-- drop function if exists public.goat_set_updated_at();
-- drop function if exists public.goat_add_check_if_missing(text, text, text);
-- drop function if exists public.goat_assert_constraint_clean(text, text, text);
-- drop function if exists public.goat_validate_constraint_if_needed(text, text);

-- Do not add any statement here that removes a table, column, auth user or row.

-- commit;
