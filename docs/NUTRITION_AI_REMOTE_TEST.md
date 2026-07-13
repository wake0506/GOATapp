# Nutrition AI Remote Test

This is an operator-run smoke test for an already deployed `nutrition-ai` Edge
Function. It uses a test account and performs at most one provider-backed AI
request. The repeated request reuses the same `clientRequestId` and should be
served by the idempotency cache.

The script reads only these environment variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GOAT_TEST_EMAIL`
- `GOAT_TEST_PASSWORD`

It never prints the password, access token, Supabase key, request body, or AI
response. Do not use a production user's credentials. The account should be a
dedicated test user with no sensitive data.

## Run

In PowerShell, set the four variables in the current session, then run:

```powershell
$env:SUPABASE_URL = 'https://your-project.supabase.co'
$env:SUPABASE_ANON_KEY = '<publishable-or-anon-key>'
$env:GOAT_TEST_EMAIL = '<test-account-email>'
$env:GOAT_TEST_PASSWORD = '<test-account-password>'
powershell -ExecutionPolicy Bypass -File .\scripts\test_nutrition_ai_remote.ps1
```

The script reports only individual `PASS`/`FAIL` lines and a final summary.
It checks anonymous authorization, test-account login, one normal AI request,
the same-request idempotency result, invalid JSON, empty text, and CORS
preflight behavior.

Run this only after the Dashboard SQL scripts 02 through 08 have been applied
and the Edge Function has been deployed. No production deployment is made by
the script.
