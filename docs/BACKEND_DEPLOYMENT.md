# Backend Deployment Runbook

This document describes the production boundary. The current phase stops before every remote write.

## Local validation

1. Install and verify the Supabase CLI and Docker Desktop.
2. Run `supabase start`.
3. Run `supabase db reset` only against the local project.
4. Run `supabase test db`.
5. Run `supabase functions serve nutrition-ai --no-verify-jwt` for local handler checks.

No real DeepSeek key belongs in local tests. Use a fake upstream client or a local test response.

## Required human confirmation before production

1. Run `supabase login` interactively.
2. Confirm the linked Supabase project ID and environment.
3. Confirm a current remote database backup and a rollback owner.
4. Set `DEEPSEEK_API_KEY` through the approved secret manager or `supabase secrets set` after review.
5. Review the generated SQL and existing row counts.

Only after those confirmations may an operator run `supabase db push` and then `supabase functions deploy nutrition-ai`.

## Rollback

Do not delete tables or compatibility columns. Roll back the client to the prior Git commit, disable incremental sync, and restore a database backup only through the approved Supabase recovery process. Tombstones and versioned rows must be retained during rollback analysis.

## Dangerous commands

Never run `supabase db push`, `supabase functions deploy`, `supabase secrets set`, `drop schema public cascade`, `truncate`, or a remote `supabase db reset` as part of automated work in this repository.
