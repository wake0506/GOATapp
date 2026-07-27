# Production preflight baseline (read-only)

- Project ref: `anqzlobatxkpeyimwbrv`
- Captured: 2026-07-27
- Connection check: `select 1` PASS
- Compatibility migration SHA-256: `6B154BC6AB31794EA178530D0874F7202C845A7D4560CEC3764F537DDA205057`
- Migration CLI state: `20260713000000`, `20260715000000`, and `20260725000000` pending; `20260727000000` local only.
- Preflight reviewed drift: chat_history PUBLIC/ALL policy; no ON DELETE CASCADE FK; Stage 3C and Contract Alignment objects absent; versioned_sync table absent.

## Stage 0 row counts

| table | rows |
| --- | ---: |
| ai_usage_daily | 0 |
| body_weight_logs | 2 |
| chat_history | 1 |
| client_operations | 0 |
| daily_tracking | 2 |
| diet_logs | 0 |
| exercise_logs | 0 |
| food_dictionary | 0 |
| training_sessions | 0 |
| user_profiles | 1 |
| water_intake_records | 1 |

This file contains no credentials, tokens, URLs with credentials, or user
content. It is a read-only baseline; production migration has not yet run.
