# Production-safe containment and forward-fix plan

This is an approval-gated plan, not an executed production rollback. It is
additive-safe: it preserves Stage 0 tables, rows, auth users, migrations,
RLS, idempotency records and `versioned_sync=false`.

## Containment

1. Stop and identify the exact production ref. Do not use a linked-project
   default or a test-project credential.
2. Record a read-only baseline: migration state, row counts/digests for Stage
   0 and Contract Alignment tables, feature-flag values, function source
   hashes, RLS/policy checks and orphan checks.
3. Set only the `nutrition_ai` client feature flag to `false` through the
   service-role-controlled path, preserving its prior value in the change
   record. This is reversible and changes no data.
4. Treat the flag as a client gate, not a server kill switch: the deployed
   Functions do not currently consult `app_feature_flags`. If direct server
   invocation must be stopped, use the separately approved Supabase Function
   availability control or revoke only the named AI RPC grants as an
   emergency containment action. Never drop RPCs, tables, columns, policies,
   rows or auth users.
5. Re-run read-only verification. Stop on any count change, orphan, RLS
   change, permission expansion or unexpected object.

## Forward-fix recovery

1. Deploy only the previously hashed, reviewed Function source to the
   explicitly identified target. Do not use `--prune`.
2. Restore `nutrition_ai` to the recorded pre-containment value and keep
   `versioned_sync=false`.
3. Run OPTIONS/401/invalid-body smoke checks, then one disposable-account
   valid request. Verify response contract, idempotent replay, quota and
   `client_operations` invariants. Do not use a primary account.
4. Compare the post-fix baseline. A rollback is accepted only when data,
   RLS, permissions, triggers, foreign keys and function hashes match the
   approved target state.

## QASZ validation evidence

The same reversible sequence was executed only in the independent qasz test
project. The containment flag committed as disabled; Stage 0 and idempotency
row counts stayed unchanged; the original flag was restored; a fresh valid
nutrition request returned HTTP 200 with the expected contract; the test
account was deleted; counts returned to baseline; and `versioned_sync` stayed
false. Evidence:

`artifacts/backend_contract_alignment/results/qasz_containment_forward_fix.log`

The executable helper is explicitly named for qasz and must not be used on
production:

`scripts/test_qasz_containment_forward_fix.ps1`

## Stop conditions

Authentication failure, identity ambiguity, any migration or verification
FAIL/REVIEW, provider contract failure, replay mismatch, quota/provider
duplication, orphan, secret leakage, unexpected object or data-count change
requires STOP and a separate review. The test-only destructive rollback file
remains prohibited in production.
