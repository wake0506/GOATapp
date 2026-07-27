# GOATapp Backend Contract Alignment Final Local Report

Date: 2026-07-26

## Result

Local acceptance: PASS.

Windows native Deno 2.9.4 remains blocked by the host runtime:

- Unexpected client pipe failure, Windows error 6, exit code 1.
- Official Linux denoland/deno:2.9.4 image digest:
  sha256:c777b4b225501a61074837e90a826a58f99124837824023cd60334b1e2374498.
- Linux single test: 25/25 PASS.
- Linux full run 1: 37/37 PASS.
- Linux full run 2: 37/37 PASS.
- Read-only bind mount left the source worktree unchanged.

The Deno conclusion is DENO_TEST_CODE_PASS and
WINDOWS_DENO_NATIVE_RUNTIME_BLOCKED. Linux PASS is not described as Windows
PASS.

## Repository baseline

- Repository: D:\GOATapp\goat_app
- Branch: feature/backend-data-services
- HEAD: 539d0955878d30a021d4d3f6e6188c44a8f89b0d
- Existing uncommitted and untracked work was preserved.
- versioned_sync remains disabled.
- Known duplicate diet_logs / exercise_logs updated_at trigger P1 was not
  modified.
- No commit, push, or production operation was performed.

## Local evidence

| Area | Result |
| --- | --- |
| Local migration apply and idempotent replay | PASS |
| Guarded rollback and reapply | PASS |
| SQL/RLS tests | 10/10 and 41/41 PASS |
| Local JWT/export/delete E2E | 37/37 PASS |
| Flutter format | 48 files, 0 changes |
| Flutter analyze | PASS; 93 existing non-fatal diagnostics |
| Flutter tests | 47/47 PASS |
| Static contract checks | 69/69 PASS |
| Deno fmt/lint/check | PASS |
| git diff --check | PASS |

Evidence is retained under artifacts/backend_contract_alignment/logs and
artifacts/backend_contract_alignment/results.

## Boundary

The independent test-project acceptance is recorded separately in
docs/BACKEND_CONTRACT_ALIGNMENT_FINAL_TEST_PROJECT_REPORT.md.
Production Supabase was not modified or deployed.
