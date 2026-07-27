# GOATapp Backend Contract Alignment Final Test Project Report

Date: 2026-07-26

## Result

Independent test project acceptance: READY_FOR_PRODUCTION_APPROVAL.

The project was verified as GOATapp Backend Test. Only the test ref suffix
qasz is recorded here; the production ref was different. The database URL was
not written to this report.

## Connection and baseline

- PostgreSQL connection succeeded through the 6543 transaction pooler.
- The configured 5432 session-pooler URL rejected authentication; 6543 was
  used only in process memory.
- Read-only SELECT 1: PASS.
- Read-only preflight: 6/6 PASS.
- Baseline snapshot: artifacts/backend_contract_alignment/snapshots/remote_test_before.
- versioned_sync=false.
- No production project was linked or modified.

## Remote migration and database acceptance

- Contract Alignment migration first apply: PASS.
- Idempotent replay: PASS.
- Post-apply verification: PASS.
- SQL/RLS contract tests: PASS.
- Stage 0 objects and data remained present.
- Known duplicate updated_at trigger P1 was not changed.

## Real JWT and data-contract E2E

- USER1, USER2 and dedicated USER_DELETE were random disposable accounts.
- USER1/USER2 own-row CRUD and cross-user read/update/spoof attacks: PASS.
- Anonymous access denial: PASS.
- Training JSON with optional and unknown fields: PASS.
- Idempotency isolation and duplicate rejection: PASS.
- Export allow-list, no-store, user isolation and internal-field exclusion:
  PASS.
- Dedicated delete-account confirmation, cascade cleanup, authentication
  invalidation and unaffected users: PASS.
- Final run: 40 checks PASS.
- Test accounts were cleaned; USER_DELETE was removed through delete-account.

## Edge Functions

All four functions were deployed with explicit test-project ref:

- nutrition-ai
- coach-ai
- export-user-data
- delete-account

Source hashes and deployment output are retained in
artifacts/backend_contract_alignment/results/remote_function_sha256_manifest.txt
and artifacts/backend_contract_alignment/results/remote_function_deploy.log.
Authenticated invalid-body and OPTIONS checks for coach-ai and nutrition-ai
passed without invoking a model provider. Export and delete were tested with
real JWTs.
Authenticated valid provider requests then passed for both nutrition-ai and
coach-ai. Nutrition returned HTTP 200 with the expected response contract;
coach returned HTTP 200 with the expected structured response. Nutrition
duplicate operation replay returned the same response, and the same operation
ID used by a second user remained isolated. Evidence is retained in
`remote_nutrition_ai_provider_e2e.log` and `remote_coach_ai_provider_e2e.log`.

The required failure-recovery sequence passed after the model compatibility
fix. A temporary invalid test-project `DEEPSEEK_API_KEY` produced `502
AI_PROVIDER_ERROR`; the failed claim row was absent. After restoration, a
fresh operation returned 200, the same failed operation retried with 200, and
its row became `COMPLETED_RESPONSE`. Quota and operation evidence showed no
duplicate charge or Provider call. A follow-up three-client replay diagnostic
then returned HTTP 200 from PowerShell, Windows curl HTTP/1.1 and Linux curl;
all canonical response hashes matched and database/quota state stayed fixed.
Evidence: `remote_provider_failure_recovery_final.log` and
`replay_transport_diagnostic.log`.

## Provider configuration gate

Both Functions read `DEEPSEEK_API_KEY` and use model `deepseek-v4-flash`. The
nutrition endpoint is `https://api.deepseek.com/v1/chat/completions`; coach-ai
uses `https://api.deepseek.com/chat/completions`; both use a 20-second timeout.
The qasz secret was supplied through the protected test-project environment;
its value was not read into reports. Direct Provider and authenticated qasz
Function probes returned HTTP 200 with the expected contracts.

## Latest model compatibility result

The user supplied a directly validated test model, `deepseek-v4-flash`. The
four backend nutrition/coach deployment copies were minimally updated from
`deepseek-chat` to `deepseek-v4-flash`; endpoints, timeout, contracts,
permissions and idempotency code were not changed. Local Deno gates could not
start because Docker Desktop's Linux Engine remained unavailable after a
bounded startup attempt. Docker was subsequently restored and all Deno/static
gates passed, but `flutter test --no-pub` produced no output for more than five
minutes and was stopped. No Function was redeployed and no remote test was run
after this change. Deno, static and Flutter gates then passed. Only
nutrition-ai and coach-ai were redeployed to qasz; export-user-data and
delete-account were not redeployed. Evidence: `model_compatibility_before_after_sha256.txt`
and `model_fix_qasz_deploy.log`.

## Controlled Provider failure recovery

After the model update, a fresh operation returned 200. A temporary invalid
test secret produced 502 `AI_PROVIDER_ERROR`; the immediate database snapshot
showed the failed operation row was absent, directly proving the release path
deleted the retry lease. After restoring the protected env-file secret, a new
verification operation returned 200 and the same failed operation retried with
200. Its database row became `COMPLETED_RESPONSE`; quota evidence remained
three unique operation IDs with no duplicate charge observed.

The initial Python replay attempt returned transport status 0 while the
database snapshot still showed the completed cached response. The follow-up
three-client run returned HTTP 200 from all clients with identical canonical
responses and unchanged database/quota state.

## Read-only idempotency audit

The deployed SQL defines `nutrition_ai_release_operation(uuid, text, uuid)`
as a service-role-only `SECURITY DEFINER` function that deletes only the
matching user, operation, entity type, claim token and null-response row, and
returns `found`. The Function awaits this RPC on Provider failure but checks
only `released.error`, not the returned boolean. This is a review finding;
because the fresh operation failed before historical-operation analysis, no
code change was made and no claim-release defect was asserted as proven.

## Rollback and reapply

- Guarded test-only rollback: PASS.
- Stage 0 digest unchanged across rollback: PASS.
- Contract Alignment tables, policies, triggers and protection function were
  absent after rollback; prior deletion-readiness function remained.
- Reapply: PASS.
- Final read-only verification and SQL/RLS tests after reapply: PASS.
- Final JWT/export/delete E2E after reapply: PASS.
- Qasz containment/forward-fix: PASS. Reversible `nutrition_ai=false`
  containment preserved Stage 0 and idempotency counts; the original flag was
  restored, a fresh valid request returned 200, the disposable account was
  deleted, counts returned to baseline and `versioned_sync` stayed false.

## Evidence

- artifacts/backend_contract_alignment/results/remote_test_preflight.log
- artifacts/backend_contract_alignment/results/remote_migration_first_apply.log
- artifacts/backend_contract_alignment/results/remote_migration_idempotent_replay.log
- artifacts/backend_contract_alignment/results/remote_final_verification.log
- artifacts/backend_contract_alignment/results/remote_final_sql_tests.log
- artifacts/backend_contract_alignment/results/remote_guarded_rollback.log
- artifacts/backend_contract_alignment/results/remote_rollback_verification.log
- artifacts/backend_contract_alignment/results/remote_reapply.log
- artifacts/backend_contract_alignment/results/remote_final_function_e2e.log
- artifacts/backend_contract_alignment/results/remote_nutrition_ai_provider_e2e.log
- artifacts/backend_contract_alignment/results/remote_coach_ai_provider_e2e.log
- artifacts/backend_contract_alignment/results/remote_provider_failure_recovery.log
- artifacts/backend_contract_alignment/results/failure_recovery_fresh_operation.log
- artifacts/backend_contract_alignment/results/deepseek_direct_probe.log
- artifacts/backend_contract_alignment/results/replay_transport_diagnostic.log
- artifacts/backend_contract_alignment/results/qasz_containment_forward_fix.log

## Production boundary

Production migration, production Edge Function deployment, commit and push:
NO.

Final status:
BACKEND_CONTRACT_ALIGNMENT_READY_FOR_PRODUCTION_APPROVAL

Replay transport, Provider recovery and qasz containment/forward-fix gates are
PASS. Production remains untouched; this status is not production approval.
