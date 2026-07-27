# GOATapp Frontend/Backend Contract

Audit date: 2026-07-25

Frontend source: `D:\GOATapp\goat_app_frontend_stage0`

Frontend checkpoint: `42a8b23f21ad4ee50d1277008670c10e94a7598b`

Stage 3B status: code present in a dirty working tree; final frontend commit is
not confirmed.

## Field contract

`PERSISTED LOCAL` describes the frontend repository at the audited checkpoint
plus its current uncommitted Stage 3B files. `EXPECTED REMOTE` describes the
backend draft in `20260725000000_backend_contract_alignment.sql`.

### Completed training

| FRONTEND MODEL | FIELD | TYPE | OPTIONAL | PERSISTED LOCAL | EXPECTED REMOTE | BACKWARD COMPATIBILITY |
| --- | --- | --- | --- | --- | --- | --- |
| TrainingSession | id | String | No | snapshot JSON | `training_sessions.id` | Existing IDs unchanged |
| TrainingSession | name | String | No | snapshot JSON | `training_sessions.name` | Defaults to `训练` when old JSON omits it |
| TrainingSession | date | String | No | snapshot JSON | `training_sessions.date` | Existing business-date shape retained |
| TrainingSession | exercises | List\<TrainingExercise> | No | snapshot JSON | `training_sessions.exercises` JSONB array | Old minimal exercises remain valid |
| TrainingSession | userId | — | — | Not a Dart field | `training_sessions.user_id`, derived from JWT | Never accepted from AI output |
| TrainingSession | startedAt/completedAt | — | — | Not serialized for completed sessions | Not added | Remains a documented frontend gap |
| TrainingExercise | exerciseId | String? | Yes | nested JSON | nested JSONB | Null remains valid for legacy records |
| TrainingExercise | exerciseName | String | No | nested JSON | nested JSONB | Old fallback `未命名动作` retained |
| TrainingExercise | bodyPart | String | No | nested JSON | nested JSONB | Old fallback `全身` retained |
| TrainingExercise | sets | List\<SetRecord> | No | nested JSON | nested JSONB, order retained | Empty list remains valid |
| TrainingExercise | orderIndex | int? | Yes | nested JSON | nested JSONB | Array order remains authoritative fallback |
| TrainingExercise | status | TrainingExerciseStatus? | Yes | nested JSON | nested JSONB | Missing value remains null |
| TrainingExercise | substitutedFromExerciseId | String? | Yes | nested JSON | nested JSONB | Missing value remains null |
| TrainingExercise | supersetGroupId | String? | Yes | nested JSON | nested JSONB | Missing value remains null |
| TrainingExercise | progressionTarget | ProgressionTarget? | Yes | nested JSON | nested JSONB | Null is preserved; no synthetic target |
| TrainingExercise | restPrescription | RestPrescription? | Yes | nested JSON | nested JSONB | Null is preserved |
| SetRecord | id | String? | Yes | nested JSON | nested JSONB | Missing IDs remain null |
| SetRecord | weight | double | No | nested JSON | nested JSONB numeric | Numeric strings remain a frontend compatibility concern |
| SetRecord | reps | int | No | nested JSON | nested JSONB numeric | Old missing value defaults to zero |
| SetRecord | type | String | No | nested JSON | nested JSONB | Legacy Chinese values retained |
| SetRecord | restSeconds | int | No | nested JSON | nested JSONB | Legacy field retained |
| SetRecord | durationSec | int | No | nested JSON | nested JSONB | Legacy default retained |
| SetRecord | setType | TrainingSetType? | Yes | nested JSON | nested JSONB | Legacy `type` still resolves old records |
| SetRecord | rir | int? | Yes | nested JSON | nested JSONB | Frontend validates 0–3 |
| SetRecord | rpe | double? | Yes | nested JSON | nested JSONB | Frontend validates 1–10 |
| SetRecord | reachedFailure | bool? | Yes | nested JSON | nested JSONB | Missing value remains null |
| SetRecord | completedAt | DateTime? | Yes | UTC ISO-8601 | nested JSONB string | Missing value remains null |
| SetRecord | replacementPlaceholder | bool | No | nested JSON | nested JSONB | Old records default false |
| SetRecord | recommendedRestSeconds | int? | Yes | nested JSON | nested JSONB | Missing value remains null |
| SetRecord | plannedRestSeconds | int? | Yes | nested JSON | nested JSONB | Missing value remains null |
| SetRecord | actualRestSeconds | int? | Yes | nested JSON | nested JSONB | Missing value remains null |
| SetRecord | restPolicyVersion | int? | Yes | nested JSON | nested JSONB | V2 values use `2`; old values remain null |
| SetRecord | restSource | RestSource? | Yes | enum name | nested JSONB | Unknown values become null in Dart |

The server does not deserialize or reconstruct `exercises`. PostgreSQL stores
the whole JSONB array, so unknown optional keys and array order survive a
database round trip.

### Progression and rest

| FRONTEND MODEL | FIELD | TYPE | OPTIONAL | PERSISTED LOCAL | EXPECTED REMOTE | BACKWARD COMPATIBILITY |
| --- | --- | --- | --- | --- | --- | --- |
| ProgressionTarget | targetSets | int | No | session/template JSON | JSONB | Must be positive |
| ProgressionTarget | targetRepMin | int | No | session/template JSON | JSONB | Must not exceed max |
| ProgressionTarget | targetRepMax | int | No | session/template JSON | JSONB | Must be positive |
| ProgressionTarget | weightStepKg | double? | Yes | session/template JSON | JSONB | Null remains null |
| RestPrescription | mode | recommended/fixed | No | session/template JSON | JSONB | Exact enum name retained |
| RestPrescription | fixedSeconds | int? | Yes | session/template JSON | JSONB | Only emitted for valid fixed mode |
| RestPrescription | policyVersion | — | — | Not serialized by current Dart model | JSONB can preserve it if later added | Frontend gap; SetRecord already persists version 2 |

No migration inserts a default `ProgressionTarget`.

### Training templates

| FRONTEND MODEL | FIELD | TYPE | OPTIONAL | PERSISTED LOCAL | EXPECTED REMOTE | BACKWARD COMPATIBILITY |
| --- | --- | --- | --- | --- | --- | --- |
| TrainingTemplate | id | String | No | namespaced SharedPreferences | `(user_id,id)` key | Stable ID retained |
| TrainingTemplate | name | String | No | namespaced SharedPreferences | `name` | Blank names rejected remotely |
| TrainingTemplate | exerciseIds | List\<String> | No | ordered JSON list | `exercise_ids` JSONB array | Order retained |
| TrainingTemplate | progressionTargets | Map\<String,ProgressionTarget> | No | JSON object | `progression_targets` JSONB object | Missing map remains empty |
| TrainingTemplate | restPrescriptions | Map\<String,RestPrescription> | No | JSON object | `rest_prescriptions` JSONB object | Missing map remains empty |
| TrainingTemplate | supersetGroups | — | — | Not serialized by current frontend | `superset_groups` JSONB object reserved | Backend-ready, frontend pending |
| TrainingTemplate | createdAt/updatedAt/deletedAt | — | — | Not in current Dart model | server metadata | Frontend sync adapter pending |

`TrainingTemplate`, `ActiveTrainingSession`, and completed
`TrainingSession` remain separate entities. Active sessions and live timer
state are not synchronized.

### AI memory and profile projection

| FRONTEND MODEL | FIELD | TYPE | OPTIONAL | PERSISTED LOCAL | EXPECTED REMOTE | BACKWARD COMPATIBILITY |
| --- | --- | --- | --- | --- | --- | --- |
| AiMemoryItem | id | String | No | namespaced SharedPreferences | `(user_id,id)` key | Stable local ID retained |
| AiMemoryItem | stableKey | String? | Yes | JSON | `stable_key` | Unique per user/source while active |
| AiMemoryItem | category | AiProfileCategory | No | enum name | `category` | Current enum names retained |
| AiMemoryItem | value | String | No | JSON | `value` | Human-readable value retained |
| AiMemoryItem | structuredValue | Map | No | JSON | `structured_value` JSONB | Empty object remains valid |
| AiMemoryItem | sourceType | userProvided/behaviorDerived/aiInferred | No | enum name | `source_type` | Exact Dart values retained |
| AiMemoryItem | status | active/pendingConfirmation/rejected/incorrect/archived | No | enum name | `status` | Suppression states retained |
| AiMemoryItem | createdAt | DateTime | No | UTC ISO-8601 | `created_at` | Server accepts existing timestamp |
| AiMemoryItem | updatedAt | DateTime | No | UTC ISO-8601 | `updated_at` | Trigger advances remote updates |
| AiMemoryItem | sourceRefs | List\<AiMemorySourceRef> | No | JSON | `source_refs` JSONB | Exact nested fields retained |
| AiMemoryItem | confidenceLevel | high/medium/low? | Yes | enum name | `confidence_level` | Null remains null |
| AiMemoryItem | userConfirmed | bool | No | JSON | `user_confirmed` | Active AI inference requires true |

Training goal, experience, equipment, preference, and coaching style are not
duplicated into new `user_profiles` columns. The unique source is active
`userProvided` rows in `ai_memories`; `ProfileSummaryService` remains a
projection over those rows. A database trigger prevents reclassification of a
`userProvided` memory as AI-derived.

### AI suggestions and feedback

| FRONTEND MODEL | FIELD | TYPE | OPTIONAL | PERSISTED LOCAL | EXPECTED REMOTE | BACKWARD COMPATIBILITY |
| --- | --- | --- | --- | --- | --- | --- |
| AiSuggestion | id | String | No | namespaced SharedPreferences | `(user_id,id)` key | Stable ID retained |
| AiSuggestion | type | AiSuggestionType | No | enum name | `type` | Exact Dart value retained |
| AiSuggestion | title | String | No | JSON | `title` | Retained |
| AiSuggestion | summary | String | No | JSON | `summary` | Retained |
| AiSuggestion | reasonCodes | List\<String> | No | JSON | `reason_codes` JSONB | Order retained |
| AiSuggestion | evidenceRefs | List\<String> | No | JSON | `evidence_refs` JSONB | Order retained |
| AiSuggestion | knowledgeRefs | List\<String> | No | JSON | `knowledge_refs` JSONB | Order retained |
| AiSuggestion | proposedAction | AiProposedAction? | Yes | JSON | `proposed_action` JSONB | Null remains null |
| AiSuggestion | dataQuality | high/medium/low/insufficient | No | enum name | `data_quality` | Exact value retained |
| AiSuggestion | status | proposed/accepted/modified/rejected/dismissed/applied/applyFailed | No | enum name | `status` | Current Stage 3B transition values retained |
| AiSuggestion | createdAt | DateTime | No | UTC ISO-8601 | `created_at` | Retained |
| AiSuggestion | failureMessage | String? | Yes | JSON | `failure_message` | Null remains null |
| AiSuggestion | updatedAt | — | — | Not in Dart model | server metadata | Frontend sync adapter pending |
| SuggestionFeedback | suggestionId | String | No | namespaced SharedPreferences | `suggestion_id` | Composite FK preserves ownership |
| SuggestionFeedback | decision | accepted/modified/rejected/dismissed | No | enum name | `decision` | Exact value retained |
| SuggestionFeedback | modifiedAction | AiProposedAction? | Yes | JSON | `modified_action` JSONB | Null remains null |
| SuggestionFeedback | reasonCode | SuggestionRejectionReason? | Yes | enum name | `reason_code` | Null remains null |
| SuggestionFeedback | feedbackType | SuggestionFeedbackType? | Yes | uncommitted Stage 3B JSON | `feedback_type` | Pending final frontend commit |
| SuggestionFeedback | createdAt | DateTime | No | UTC ISO-8601 | `created_at` | Retained |

## Gap Matrix

| AREA | CURRENT | REQUIRED | GAP | MIGRATION | RLS | EXPORT | DELETE | SYNC |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Completed training | Local snapshot; cloud compatibility writes `user_profiles.training_data` | Lossless `training_sessions.exercises` | Client does not use structured remote table while `versioned_sync=false` | JSON array validation only | Existing | Included | Existing cascade | Frontend adapter pending |
| Advanced set/rest history | Nested local JSON | Lossless cloud JSON | Server ready; client route pending | No column split | Existing | Included | Existing cascade | Pending |
| ProgressionTarget | Nested session/template JSON | Preserve explicit values only | Template remote table absent before this draft | JSONB maps | Own-row | Included | Cascade | Pending |
| RestPrescription V2 | Nested JSON; SetRecord has policy version | Preserve V2 and legacy fields | Template model omits policyVersion | JSONB maps | Own-row | Included | Cascade | Pending frontend field |
| Training templates | Local SharedPreferences only | User-scoped cloud entity | No remote table or sync adapter | New additive table | Own-row CRUD | Included | Cascade | Pending |
| Template Superset | Not serialized | Preserve group relation | Frontend contract missing | Reserved JSONB object | Own-row CRUD | Included | Cascade | Pending frontend field |
| Profile preferences | USER_PROVIDED AI memories, local | One cloud source | No cloud AI memory table | `ai_memories` | Own-row CRUD | `aiProfile` projection | Cascade | Pending |
| AI memories | Local only | Cloud persistence and suppression | No remote table | New table and checks | Own-row CRUD | Included | Cascade | Pending |
| AI suggestions | Local only | Cloud lifecycle persistence | No remote table | New table and checks | Own-row CRUD | Included | Cascade | Pending |
| AI feedback | Local only; Stage 3B adds feedbackType | Cloud persistence/idempotency | No remote table | New table and composite FK | Own-row CRUD | Included | Cascade | Pending |
| Idempotency | Existing `client_operations`; stable entity IDs | Reuse one system | New frontend writes not wired | Unique client operation IDs | User-scoped | Internal IDs omitted | Cascade | Pending |
| Export | Whitelist stopped at training sessions | Include new personal data | Fixed in local Edge source | None | Admin/JWT path | Extended | N/A | N/A |
| Delete account | Cascade readiness omitted future tables | Cover every new user table | Fixed in migration | Readiness RPC replaced | Service role only | N/A | Extended | N/A |
| Coach endpoint | Production `nutrition-ai` is nutrition parser | General explanation endpoint | Separate endpoint absent | None | JWT validation | N/A | N/A | Stateless |
| Test project | No accessible CLI/DB in this environment | First run, re-run, RLS, export, delete, rollback/reapply | Actual execution pending | Scripts prepared | Tests prepared | Smoke prepared | Dedicated-account test prepared | Not enabled |

## Design decisions

1. Preserve completed training as one JSONB array. The server never applies a
   lossy DTO conversion.
2. Add `training_templates`; do not synchronize `ActiveTrainingSession`.
3. Keep `ProgressionTarget` null unless the user explicitly sets it.
4. Store RestPrescription and historical rest fields; do not copy the frontend
   recommendation engine.
5. Use `ai_memories(source_type='userProvided')` as the only source for profile
   preferences. `user_profiles` remains the source for existing demographic and
   nutrition-target fields.
6. Reuse stable IDs and `client_operation_id`/`client_operations`; do not create
   a second idempotency ledger.
7. Add a separate `coach-ai` endpoint. Extending the production nutrition
   parser would couple unrelated schemas and raise backward-compatibility risk.
8. Keep `versioned_sync=false`. No migration or script enables it.
