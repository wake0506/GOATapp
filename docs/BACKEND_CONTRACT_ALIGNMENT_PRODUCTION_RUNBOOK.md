# GOATapp Backend Contract Alignment Production Runbook

This runbook is an approval-gated production procedure. It was not executed
in this task.

## Immutable safety boundary

- Use an independent test project first; never reuse its credentials for
  production.
- Keep versioned_sync=false.
- Do not modify the known diet_logs/exercise_logs duplicate trigger P1.
- Never print database URLs, passwords, JWTs, API keys or function secrets.
- Use a dedicated disposable delete-test account. Never use a primary account.
- Stop on any FAIL, REVIEW, identity mismatch, unexpected object, orphan,
  permission expansion or migration error.

## Preflight

Run from D:\GOATapp\goat_app:

    git diff --check
    supabase projects list

Confirm the selected project is production only at the explicit approval
boundary. Do not link to it before that approval. Obtain a fresh database
connection secret interactively, keep it in process memory, and run only:

    select 1;

Then execute the read-only preflight:

    psql -X --set ON_ERROR_STOP=1 --file .\supabase\contract_alignment\01_preflight_readonly.sql

Every row must be PASS. Do not continue on REVIEW or FAIL.

## Migration order

Run exactly in this order against the approved target:

1. Verify and record the existing Stage 0 baseline.
2. Apply the Contract Alignment migration:

    psql -X --set ON_ERROR_STOP=1 --file .\supabase\migrations\20260725000000_backend_contract_alignment.sql

3. Run the read-only verification:

    psql -X --set ON_ERROR_STOP=1 --file .\supabase\contract_alignment\03_post_deploy_verification_readonly.sql

4. Run the database/RLS contract tests.
5. Repeat the migration once and repeat verification to prove idempotency.

Expected result: all verification rows PASS, no duplicate policies/triggers,
no data-count change, and versioned_sync remains false.

## Function deployment order

Before deployment, verify the target ref again and compute source hashes:

    Get-FileHash .\supabase\functions\nutrition-ai\index.ts -Algorithm SHA256
    Get-FileHash .\supabase\functions\coach-ai\index.ts -Algorithm SHA256
    Get-FileHash .\supabase\functions\export-user-data\index.ts -Algorithm SHA256
    Get-FileHash .\supabase\functions\delete-account\index.ts -Algorithm SHA256

Deploy only after all SQL checks pass, with the explicit production ref:

    supabase functions deploy nutrition-ai --project-ref <PRODUCTION_REF>
    supabase functions deploy coach-ai --project-ref <PRODUCTION_REF>
    supabase functions deploy export-user-data --project-ref <PRODUCTION_REF>
    supabase functions deploy delete-account --project-ref <PRODUCTION_REF>

Never use an ambiguous linked project or the prune option.

## Post-deploy non-destructive smoke

- OPTIONS requests return 204.
- Missing JWT returns 401.
- Invalid JSON/content type returns the documented 400/415 response.
- Export is tested first with a disposable test account and has no-store.
- Delete is tested only with the dedicated delete-test account and fixed
  confirmation phrase.
- Verify USER1/USER2 isolation, no orphan rows and no secret leakage.
- Do not invoke production model calls unless separately approved.

## Rollback

The test-only rollback file is not a production rollback:

    supabase/rollbacks/20260725000000_backend_contract_alignment_test_only.sql

Do not run it in production. Production rollback must be a separately
reviewed, additive-safe migration plan that preserves Stage 0 data.

The reviewed containment and forward-fix procedure is documented in
`docs/BACKEND_CONTRACT_ALIGNMENT_PRODUCTION_ROLLBACK_PLAN.md`. It uses a
reversible client-gate change and an explicitly approved Function availability
control when a server-side stop is required; it never drops objects or data.
The qasz-only validation helper and evidence must be complete before any
production approval.

## GO / STOP conditions

The package is ready to request production approval only when the independent
test project report is complete, all local and remote checks are PASS,
rollback/reapply and qasz containment/forward-fix are PASS, and source hashes
are recorded. A separate explicit production approval is still required
before any production link, migration or Function deployment.

STOP on any identity ambiguity, authentication failure, migration error,
verification FAIL/REVIEW, RLS cross-user access, export leakage, deletion
cascade failure, orphan, permission expansion, or missing evidence.

Production deployment status for the current task: NO.
