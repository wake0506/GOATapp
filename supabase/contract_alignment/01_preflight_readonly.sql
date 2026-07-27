/*
Read-only preflight for the contract-alignment migration.
Run against the intended project before any remote write.
Every returned row must be PASS. REVIEW requires operator investigation.
*/

with checks(check_name, status, details) as (
  values
    (
      'required_function:goat_set_updated_at',
      case
        when pg_catalog.to_regprocedure('public.goat_set_updated_at()') is not null then 'PASS'
        else 'FAIL'
      end,
      'updated_at trigger function must exist'
    ),
    (
      'required_table:training_sessions',
      case
        when pg_catalog.to_regclass('public.training_sessions') is not null then 'PASS'
        else 'FAIL'
      end,
      'completed training JSON source table'
    ),
    (
      'required_table:client_operations',
      case
        when pg_catalog.to_regclass('public.client_operations') is not null then 'PASS'
        else 'FAIL'
      end,
      'existing idempotency ledger'
    ),
    (
      'training_sessions:exercises_type',
      case
        when pg_catalog.to_regclass('public.training_sessions') is null then 'FAIL'
        when exists (
          select 1
          from public.training_sessions session_row
          where pg_catalog.jsonb_typeof(session_row.exercises) <> 'array'
        ) then 'FAIL'
        else 'PASS'
      end,
      'all existing exercises values must be JSON arrays'
    ),
    (
      'versioned_sync:disabled',
      case
        when pg_catalog.to_regclass('public.app_feature_flags') is null then 'FAIL'
        when exists (
          select 1
          from public.app_feature_flags flag_row
          where flag_row.key = 'versioned_sync'
            and flag_row.enabled = false
        ) then 'PASS'
        else 'FAIL'
      end,
      'this rollout must not enable versioned_sync'
    ),
    (
      'new_tables:deployment_shape',
      case
        when pg_catalog.to_regclass('public.training_templates') is null
         and pg_catalog.to_regclass('public.ai_memories') is null
         and pg_catalog.to_regclass('public.ai_suggestions') is null
         and pg_catalog.to_regclass('public.ai_suggestion_feedback') is null
          then 'PASS'
        when pg_catalog.to_regclass('public.training_templates') is not null
         and pg_catalog.to_regclass('public.ai_memories') is not null
         and pg_catalog.to_regclass('public.ai_suggestions') is not null
         and pg_catalog.to_regclass('public.ai_suggestion_feedback') is not null
          then 'PASS'
        else 'FAIL'
      end,
      'all four tables must be absent for first run or present for an idempotent re-run'
    )
)
select check_name, status, details
from checks
order by check_name;
