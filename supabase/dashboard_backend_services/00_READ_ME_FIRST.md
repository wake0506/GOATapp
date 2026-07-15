# GOAT Phase 3C Dashboard package

1. Run `10_schema.sql` in the Supabase Dashboard SQL Editor.
2. Run `11_rls_and_permissions.sql`.
3. Run `12_verification_readonly.sql`; deploy nothing unless every row is `PASS`.
4. Only then deploy `export-user-data` and `delete-account` from this folder.

Do not alter or rerun the prior `dashboard_deploy/02` through `08` scripts. Do
not use the Table Editor for these schema changes. Never put a service-role key
in Flutter or source control. This package is for manual Dashboard deployment;
the migration remains the source of truth for CLI/local environments.
