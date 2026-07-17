# Backend services Dashboard deployment

This runbook is for the Phase 3C package at
`supabase/dashboard_backend_services`. It is a manual Supabase Dashboard
procedure. Codex does not run the remote SQL or deploy either Edge Function.

## Database order

1. In Supabase Dashboard, open **Database → Backups** and confirm a current
   backup and an owner for rollback.
2. Open the SQL Editor and run `10_schema.sql` as one statement batch.
3. Stop immediately on any SQL error. Do not continue to `11`.
4. After `10` succeeds, run `11_rls_and_permissions.sql` as one batch.
5. After `11` succeeds, run `12_verification_readonly.sql`.
6. Continue only when every key row is `PASS`. Any `FAIL` stops the rollout;
   any `REVIEW` requires a human explanation and explicit approval.

Use `scripts/copy_dashboard_sql.ps1 -File ...` to copy a file as UTF-8 to the
clipboard. The helper prints only the file name, character count, and SHA256;
it never prints source text or credentials.

Do not use Table Editor to create, alter, drop, or manually edit these objects.
Do not run the package twice after a partial failure without reviewing the
transaction result and the current catalog state.

## Function order

Only after the database verification is all `PASS`:

1. Deploy `supabase/dashboard_backend_services/export-user-data/index.ts` as
   the Function named `export-user-data`.
2. Deploy `supabase/dashboard_backend_services/delete-account/index.ts` as
   the Function named `delete-account`.
3. Test export first with a non-production test account.
4. Create or use a dedicated disposable deletion test account only after the
   export test is all `PASS`.
5. Never use the primary account for the first deletion test.

The project currently has no Supabase Storage user-file references. If uploads
are introduced later, stop and design server-side deletion limited to the
current user's Storage directory before enabling account deletion.

## Local checks before a remote operation

```powershell
dart format .
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
flutter test --no-pub
git diff --check
Get-Command .\scripts\test_export_user_data_remote.ps1 -Syntax
Get-Command .\scripts\test_delete_account_remote.ps1 -Syntax
```

The remote scripts read only the explicitly documented environment variables.
They do not create accounts, print tokens, print response bodies, or retain
temporary export data after completion.
