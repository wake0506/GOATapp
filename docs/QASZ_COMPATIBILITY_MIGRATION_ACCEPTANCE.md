# QASZ Compatibility Migration Acceptance Report

Status: **PASS — compatibility SQL and independent qasz regression**

Date: 2026-07-27

## Execution boundary

- Test project target: ref suffix qasz.
- Production was not connected or modified.
- qasz Functions nutrition-ai and coach-ai were deployed only to qasz.
- No production migration, production Function deployment, production account,
  export, delete, commit or push was performed.
- The qasz database URL and API keys were supplied only in process through
  protected environment handling. Values are not recorded here.

## Results

| Gate | Result | Evidence |
|---|---|---|
| qasz container select 1 | PASS | postgres:17-alpine |
| compatibility draft first apply | PASS | committed successfully |
| repeated apply | PASS | idempotent |
| qasz SQL/RLS/JWT/JSON | PASS | 41/41 |
| chat_history FK/RLS/cross-user | PASS | CASCADE, no PUBLIC/anon policy, own-row CRUD, cross-user blocked |
| nutrition/coach Provider | PASS | nutrition and coach HTTP 200 |
| export/delete | PASS | authenticated export and dedicated delete account |
| rollback/reapply | PASS | guarded test rollback, expected verification FAIL, forward reapply PASS |
| containment/forward-fix | PASS | flag restored, counts stable, test account cleaned |
| final read-only verification | PASS | 19/19 plus chat_history checks |
| Deno fmt/lint/check | PASS | denoland/deno:2.9.4 |
| Deno unit tests | PASS | 37 passed, 0 failed |
| Flutter tests | PASS | 379 passed |
| local adoption simulation | PASS | empty history, data-count preservation, rollback |
| qasz migration repair adoption | PASS | applied old 3 versions, dry-run showed only 20260727000000, then reverted history |

## chat_history acceptance

qasz verification proved:

- the existing row remained present;
- user_id references auth.users.id with ON DELETE CASCADE;
- the PUBLIC/ALL policy was removed;
- authenticated own-row SELECT/INSERT/UPDATE/DELETE policies were present;
- cross-user read, update and delete attempts were blocked;
- no orphan user_id rows remained.

## Test harness fixes

The remote E2E harness now sends JSON as UTF-8 bytes and constructs the Chinese
meal type from Unicode code points so Windows PowerShell does not corrupt the
API contract. Business Functions were not changed.

## Migration history status

qasz migration list still reports the three historical local files as pending
because the compatibility file is intentionally still outside
supabase/migrations. The production adoption design is documented separately
and was validated locally in a transaction that rolled back.

## Production gate

Compatibility migration acceptance is PASS. Production remains untouched and
requires explicit approval of the migration-history adoption runbook before
any formal migration or Function deployment.
