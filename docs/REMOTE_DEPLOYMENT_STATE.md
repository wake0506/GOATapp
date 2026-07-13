# Remote Deployment State

Last recorded state: 2026-07-14.

- The user confirmed that Supabase Dashboard SQL scripts 02 through 08 were executed successfully.
- This is a user-confirmed deployment state, not an automated database verification result.
- The `nutrition-ai` Edge Function is deployed in Supabase Dashboard, based on user confirmation. This has not been automatically verified by Codex.
- `DEEPSEEK_API_KEY` is configured in Supabase Dashboard Edge Function Secrets, based on user confirmation. Its value was not read or recorded.
- Versioned multi-device sync remains disabled by default. A dedicated QA build may opt in with `--dart-define=ENABLE_VERSIONED_SYNC=true`; see `docs/SYNC_ROLLOUT_TEST_PLAN.md` before enabling it.
- No remote deployment or production database operation was performed by Codex in this task.
