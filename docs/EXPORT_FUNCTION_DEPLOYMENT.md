# `export-user-data` Dashboard deployment and test

Deploy only after `10_schema.sql`, `11_rls_and_permissions.sql`, and
`12_verification_readonly.sql` have completed with all required rows `PASS`.

1. In Supabase Dashboard, open **Edge Functions** and create/open the Function
   named `export-user-data`.
2. Paste the UTF-8 source from
   `supabase/dashboard_backend_services/export-user-data/index.ts` using
   `scripts/copy_dashboard_sql.ps1 -File export-user-data/index.ts`.
3. Confirm the Function source hash matches the formal source under
   `supabase/functions/export-user-data/index.ts`.
4. Deploy the Function from the Dashboard.
5. Set the current PowerShell environment variables without printing them:

   ```powershell
   $env:SUPABASE_URL = 'https://<project-ref>.supabase.co'
   $env:SUPABASE_ANON_KEY = '<anon-key>'
   $env:GOAT_TEST_EMAIL = '<non-production-test-account>'
   $env:GOAT_TEST_PASSWORD = '<test-password>'
   ```

6. Run `scripts/test_export_user_data_remote.ps1`.
7. Continue only when its summary is all `PASS`.

The test verifies authenticated HTTP 200, valid JSON, the complete allow-listed
top-level data sections (including `foodDictionary`), and absence of
`access_token`, `refresh_token`, `service_role`, `claim_token`,
`client_operation_id`, and `DEEPSEEK_API_KEY`. It writes a temporary JSON file
only during the test and removes it in `finally`.

The Function must keep `Cache-Control: no-store`, the 5 MiB export limit, JWT
verification, admin access only on the server, and requestId/result/bytes-only
logging. Do not print the response body or the test account credentials.
