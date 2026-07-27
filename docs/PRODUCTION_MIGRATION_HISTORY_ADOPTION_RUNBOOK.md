# Production Migration History Adoption Runbook

Status: **Designed and locally rehearsed; production not executed**

Target: production ref anqzlobatxkpeyimwbrv. The independent qasz gate is now
PASS; explicit production approval is still required.

## Why direct db push is prohibited

The production schema already contains the Stage 0 objects, but
supabase migration list reports these local migrations as pending:

- 20260713000000_backend_production.sql
- 20260715000000_backend_data_services.sql
- 20260725000000_backend_contract_alignment.sql

Applying all three would replay historical migrations against a manually
provisioned schema. The compatibility migration is additive and must be the
only SQL migration applied after history adoption.

## Files

- Draft under review:
  supabase/contract_alignment/20260727000000_production_compatibility_draft.sql
- Formal destination after qasz PASS:
  supabase/migrations/20260727000000_production_compatibility.sql
- Read-only drift preflight:
  supabase/contract_alignment/production_preflight_drift_safe.sql

The draft must be byte-reviewed and then moved into migrations only after qasz
acceptance. Do not copy test data into the migration.

## Exact approval-gated order

Run from D:\GOATapp\goat_app with a fresh production database password held
only in process memory.

1. Confirm the explicit ref and read-only baseline:

    supabase link --project-ref anqzlobatxkpeyimwbrv
    supabase migration list --linked
    supabase db query --linked "select 1;"
    supabase db query --linked --file .\supabase\contract_alignment\production_preflight_drift_safe.sql

 2. Continue only when the baseline is unchanged, the compatibility source hash
    is recorded, and every EXPECTED_DRIFT row exactly matches the reviewed qasz
    baseline. EXPECTED_DRIFT is not a blanket waiver.

3. Adopt the three already-provisioned historical versions without executing
   their SQL:

    supabase migration repair --status applied --linked 20260713000000 20260715000000 20260725000000

4. Confirm history adoption before any SQL write:

    supabase migration list --linked
    supabase db push --dry-run --linked

   The dry-run must list only the new compatibility version
   20260727000000. If any old version is pending, STOP.

This exact repair/list/dry-run sequence was executed in qasz and then
reverted, leaving qasz history in its original blank state. No migration SQL
was executed by the dry-run.

5. Apply only the compatibility migration:

    supabase db push --linked

6. Run the read-only post-deploy verification and database/RLS tests. Confirm
   Stage 0 counts, chat_history row count, CASCADE FK, no PUBLIC/ALL policy,
   authenticated own-row CRUD, versioned_sync=false and no orphan user_id.

7. Repeat the compatibility migration in the independent qasz project first.
   Production idempotency is a separate approval gate.

## Containment and rollback

- Never run the test-only rollback SQL in production.
- On any failure, stop Function deployment and preserve all rows.
- Disable only the approved nutrition_ai feature flag through the reviewed
  service-role path if server-side containment is required.
- Redeploy the previously hashed Function source as the forward fix; do not
  drop tables, revoke unrelated permissions, truncate data or delete users.
- Re-run read-only counts, policy, FK, orphan and versioned_sync checks.
- A migration history repair is not a data rollback. Never mark a migration
  reverted unless the replacement SQL and impact have been separately reviewed.

## GO conditions

- qasz compatibility apply/reapply, SQL/RLS/JWT/JSON, Provider,
  export/delete, rollback/reapply and final verification all PASS;
- local adoption simulation PASS;
- production preflight matches the reviewed drift;
- source hashes and counts are recorded;
- explicit production approval is present.

## STOP conditions

Authentication failure, identity ambiguity, unexpected schema/column/policy/
function, orphan rows, data-count change, migration error, any FAIL/REVIEW row,
secret leakage, production ref mismatch, compatibility hash mismatch,
versioned_sync not false, or a dry-run containing anything besides
20260727000000. Only the explicitly reviewed EXPECTED_DRIFT rows may remain
before adoption; no blanket FAIL/REVIEW bypass is permitted.
