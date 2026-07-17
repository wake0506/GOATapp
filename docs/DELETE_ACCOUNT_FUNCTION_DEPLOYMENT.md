# `delete-account` Dashboard deployment and test

This Function is destructive. Never test it with the primary account, an
unknown account, or an account that contains irreplaceable data.

1. Confirm the database scripts completed with all required verification rows
   `PASS`.
2. In Supabase Dashboard, create/open the Function named `delete-account`.
3. Paste the UTF-8 source from
   `supabase/dashboard_backend_services/delete-account/index.ts` using
   `scripts/copy_dashboard_sql.ps1 -File delete-account/index.ts`.
4. Confirm the source hash matches
   `supabase/functions/delete-account/index.ts`, then deploy.
5. Use only a dedicated disposable account whose email contains
   `delete-test`. The test script rejects other account names and never creates
   an account automatically.
6. Set these PowerShell environment variables without printing them:

   ```powershell
   $env:SUPABASE_URL = 'https://<project-ref>.supabase.co'
   $env:SUPABASE_ANON_KEY = '<anon-key>'
   $env:GOAT_DELETE_TEST_EMAIL = '<delete-test-account>'
   $env:GOAT_DELETE_TEST_PASSWORD = '<test-password>'
   ```

7. Run `scripts/test_delete_account_remote.ps1` and re-enter
   `DELETE MY ACCOUNT` when prompted.
8. Expect HTTP 204, then a failed login for the deleted test account.
9. Replace the placeholder UUID in `scripts/verify_deleted_account_cleanup.sql`
   with that test account UUID and run the SQL in the Dashboard SQL Editor.
   Every remaining row must be `0 / PASS`.

The Function accepts only a verified JWT user ID, requires JSON Content-Type,
enforces an 8 KiB UTF-8 request-body limit, requires the exact confirmation
phrase, calls the service-role readiness check, and hides raw admin errors.
Logs contain only requestId and an outcome. No Storage user files are currently
used by this project; if that changes, add server-side cleanup limited to the
current user's directory before allowing deletion.

The script does not create accounts, print tokens, print email addresses or
response bodies, and refuses to run without the dedicated-account naming rule.
