# GOATapp Production Compatibility Migration Status

Status: **READY FOR EXPLICIT PRODUCTION ADOPTION APPROVAL**

Date: 2026-07-27

## Scope

This document records the non-production work for the confirmed production
schema drift. No production migration, Edge Function deployment, account
creation, data export, account deletion, commit or push was executed.

Production target: anqzlobatxkpeyimwbrv (confirmed separately from qasz).
Independent test target: ref suffix qasz.

## Production read-only findings

- Connection and select 1: PASS.
- Stage 0 baseline tables: 11/11 present.
- sync_diagnostics, app_feature_flags: missing.
- Contract Alignment tables (training_templates, ai_memories,
  ai_suggestions, ai_suggestion_feedback): missing.
- chat_history columns are only user_id uuid NOT NULL and messages text.
- chat_history.user_id foreign key is not ON DELETE CASCADE.
- Existing chat_history policy is a PUBLIC/ALL policy and fails the client
  permission gate.
- Migration history relation is unavailable/empty from the linked read-only
  inspection; no migration is applied by this task.

The drift-safe preflight is:
supabase/contract_alignment/production_preflight_drift_safe.sql

It returns only check_name | status | details and does not reference
missing relations directly.

## Compatibility draft

The additive draft is:
supabase/contract_alignment/20260727000000_production_compatibility_draft.sql

After qasz PASS and report generation, the same SQL was copied to the formal
source:
supabase/migrations/20260727000000_production_compatibility.sql

It is intentionally outside supabase/migrations, so the production dry-run
cannot pick it up accidentally. It:

- guards the existing Stage 0 tables, trigger function, chat-history column,
  and orphan condition;
- applies the reviewed Stage 3C and Contract Alignment logic in one
  transaction;
- preserves existing rows and does not reset, truncate, delete, or copy test
  data;
- repairs the chat-history user foreign key only after the orphan check;
- removes client-wide chat-history policies and creates authenticated
  own-row CRUD policies;
- keeps versioned_sync=false.

## Local drift simulation

The draft was executed twice against the local Supabase database using the
local PostgreSQL container. Both executions committed successfully; the
second execution produced only expected idempotency notices. Static contract
checks remain 69/69 PASS.

## qasz gate

The qasz connection was retried through the requested postgres:17-alpine
container with the ignored env-file. Compatibility apply and reapply passed,
the database contract suite passed 41/41, the guarded rollback and forward
reapply passed, chat_history FK/RLS isolation passed, and the remote E2E suite
passed 43 checks including nutrition/coach HTTP 200, export and dedicated
delete cleanup.

The Deno 2.9.4 container checks passed (fmt, lint, check and 37 unit tests),
and the frontend suite passed 379/379. Production remains untouched.

The migration-history adoption sequence was also rehearsed in qasz: marking
the three historical versions applied made dry-run list only 20260727000000;
the history was then reverted to its original blank state.

## Next approval gate

1. Provide/enable the independent qasz execution toolchain and dedicated
   test-account configuration without printing secrets.
2. Run the complete qasz migration, RLS/JWT/JSON, Function, rollback and
   reapply suite.
3. Obtain explicit approval for the compatibility draft.
4. Re-run the production read-only preflight and only then apply the reviewed
   compatibility migration and deploy the four Functions.
5. Build the production APK only after deployment; perform the listed manual
   device checks without adb or automatic installation.
