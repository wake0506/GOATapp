# GOAT Phase 3C Dashboard package

1. Run `10_schema.sql` in the Supabase Dashboard SQL Editor.
2. Run `11_rls_and_permissions.sql`.
3. Run `12_verification_readonly.sql`.
4. Deploy the two Edge Functions only when every verification row is `PASS`.
5. Test `export-user-data` first with a non-production test account.
6. Test `delete-account` only with a dedicated disposable test account.
7. Never use the primary account for the first deletion test.
8. Do not manually edit or create these objects in Table Editor.

The current project does not reference Supabase Storage user files; the
`delete-account` Function therefore performs no Storage cleanup. Re-audit this
before introducing uploads, and then add a server-side cleanup restricted to
the authenticated user's directory.

Do not alter or rerun the prior `dashboard_deploy/02` through `08` scripts.
Never put a service-role key in Flutter or source control. This package is for
manual Dashboard deployment; the migration remains the source of truth for
CLI/local environments.
