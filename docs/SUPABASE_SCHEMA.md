# Supabase Schema

The phase 3A migration is additive and lives in `supabase/migrations/20260713000000_backend_production.sql`.

## User-owned tables

| Table | Purpose | Compatibility field |
| --- | --- | --- |
| `user_profiles` | Profile and targets | `training_data`, `current_weight` |
| `food_dictionary` | User food definitions | Existing food columns and IDs |
| `diet_logs` | Consumed food records | Existing nutrition and `date` fields |
| `exercise_logs` | Timed exercise records | Existing exercise columns |
| `daily_tracking` | Daily compatibility aggregate | `water_ml`, `weight_kg` |
| `water_intake_records` | Individual water events | Legacy aggregate rows become stable records |
| `body_weight_logs` | One weight value per user/business date | Daily tracking remains readable |
| `training_sessions` | Structured training sessions | `user_profiles.training_data` is retained |
| `sync_tombstones` | Explicit cross-device deletes | No snapshot-difference deletes |
| `client_operations` | Idempotent operation records | `(user_id, operation_id)` primary key |
| `ai_usage_daily` | Per-user daily AI quota | No provider key stored in the database |
| `chat_history` | Existing coach conversation storage | Existing shape is preserved; migration adds RLS only when present |

Every user-owned table has `user_id`, versioning timestamps, and RLS policies equivalent to `auth.uid() = user_id`. `user_profiles` uses `auth.uid() = id`.

## Migration behavior

- Existing tables and columns are not renamed or removed.
- Legacy `daily_tracking.water_ml` values are copied once to `legacy_water_<user>_<date>` detail records at midnight as a migration marker; the user-scoped ID prevents cross-account collisions.
- Existing daily weight rows are copied to `legacy_weight_<user>_<date>` rows without changing their value.
- `training_data` remains the source of truth until a later, separately verified backfill.
- Constraints are added as `NOT VALID` for compatibility with pre-existing rows; new writes are constrained immediately. Validation is a separate production operation after data review.
