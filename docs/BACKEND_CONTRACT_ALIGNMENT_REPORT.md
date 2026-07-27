# GOATapp Backend Frontend-Contract Alignment Report

## 1. Repository

Branch: `feature/backend-data-services`

Baseline: `539d0955878d30a021d4d3f6e6188c44a8f89b0d`

Workspace: backend has pre-existing untracked deployment materials; they were
preserved and excluded from this task. Frontend was read-only. Contract
alignment changes remain uncommitted because the independent test-project gate
has not run.

## 2. Current Backend Audit

training_sessions: existing `id text`, `user_id uuid`, `name text`, `date
date`, `exercises jsonb`, version/deletion/client-operation metadata. Before
this draft, no validated JSON-array constraint exists. Current compatibility
sync still writes completed training to `user_profiles.training_data`.

training_templates: no existing table. The draft adds a separate user-owned
entity and does not synchronize active sessions.

user_profiles: demographic data, nutrition targets, `training_data`, version
and deletion metadata. No training-goal/experience/equipment/coaching fields
are added because the frontend treats USER_PROVIDED AI memory as their source.

AI tables: no existing memory, suggestion, or feedback tables. The draft adds
`ai_memories`, `ai_suggestions`, and `ai_suggestion_feedback`.

client_operations: existing `(user_id,operation_id)` idempotency ledger. New
tables reuse stable entity IDs and `client_operation_id`; no second ledger is
created.

sync_tombstones: existing user-owned table. The draft does not enable
versioned sync.

export: local Edge source now whitelists training templates, AI profile
projection, memories, suggestions, and feedback. Internal version,
client-operation IDs, user IDs, credentials, and claim tokens are excluded.

delete: the existing JWT/fixed-phrase/service-role flow is retained. The
migration extends the cascade-readiness RPC to every new user table.

nutrition-ai: unchanged.

## 3. Frontend Contract Audit

Frontend checkpoint:
`42a8b23f21ad4ee50d1277008670c10e94a7598b`

Training fields: audited from actual Dart `toJson`/`fromJson`. Completed
sessions serialize `id`, `name`, `date`, ordered exercises, advanced set
fields, progression target, rest prescription, stable exercise ID and Superset
group ID.

Profile fields: training goal, experience, equipment, preference, and coaching
style are projected from active USER_PROVIDED AI memories.

AI fields: audited from actual memory, suggestion, proposed-action, feedback,
and state serializers.

Stage 3B fields: PENDING FINAL FRONTEND COMMIT. The dirty frontend working tree
adds `SuggestionFeedback.feedbackType`, `AiCoachUncertainty.partialData`, and
scenario explanation models.

The complete field table is in
`docs/BACKEND_CONTRACT_ALIGNMENT_CONTRACT.md`.

## 4. Gap Matrix

The detailed matrix is in
`docs/BACKEND_CONTRACT_ALIGNMENT_CONTRACT.md`.

Primary unresolved gaps:

- frontend cloud adapters for templates, AI entities, and structured completed
  sessions are not implemented in this backend-only task;
- the current TrainingTemplate serializer has no Superset field;
- RestPrescription itself does not serialize a policy version, although
  SetRecord persists `restPolicyVersion`;
- completed TrainingSession does not serialize started/completed timestamps;
- the independent test project has not been executed.

## 5. Training JSON Round-trip

New fields: FAIL — SQL test prepared, independent database not executed.

Old data: FAIL — compatibility test prepared, independent database not
executed.

Order: FAIL — exact JSON equality test prepared, independent database not
executed.

Superset: FAIL — completed-session test prepared; template frontend field is
still absent.

Rest V2: FAIL — SetRecord and template JSON tests prepared, independent
database not executed.

## 6. Training Templates

Schema: FAIL — migration draft prepared, not applied to an independent project.

CRUD: FAIL — pgTAP source prepared, not executed.

Order: FAIL — exact ordered-array test prepared, not executed.

ProgressionTarget: FAIL — null-safe JSON design and test prepared, not executed.

RestPrescription: FAIL — JSON design and test prepared, not executed.

User isolation: FAIL — RLS test source prepared, not executed.

## 7. Profile

Goal: FAIL — cloud schema prepared, frontend sync not wired/tested.

Experience: FAIL — cloud schema prepared, frontend sync not wired/tested.

Equipment: FAIL — cloud schema prepared, frontend sync not wired/tested.

Preferences: FAIL — cloud schema prepared, frontend sync not wired/tested.

Coaching style: FAIL — cloud schema prepared, frontend sync not wired/tested.

## 8. AI Data

Memory: FAIL — schema and tests prepared, independent project not executed.

Suggestion: FAIL — schema and tests prepared, independent project not executed.

Feedback: FAIL — schema and tests prepared, independent project not executed.

Pending confirmation: FAIL — constraint/test prepared, not executed.

Suppression: FAIL — statuses and USER_PROVIDED protection prepared, not
executed.

## 9. Security

RLS: FAIL — four-table own-row policies are drafted but not remotely executed.

Cross-user: FAIL — attack tests are prepared but not remotely executed.

Idempotency: FAIL — unique operation tests are prepared but not remotely
executed.

## 10. Export/Delete

Export: FAIL — source and remote smoke test now seed and verify rich training
JSON, template maps/order, AI profile/memory/suggestion/feedback, and sensitive
field exclusion, but no independent test-project execution exists.

Delete: FAIL — local failure-path tests are prepared; no independent dedicated
account deletion result exists.

No orphan: FAIL — cascade test is prepared but not executed.

## 11. AI Endpoint

Decision: NEW_COACH_AI

Backward compatibility: PASS — `nutrition-ai` is unchanged; the new endpoint
has a separate request/response contract and JWT boundary.

Production deployed: NO

## 12. Test Project

First run: FAIL — not executed.

Re-run: FAIL — not executed.

Rollback: FAIL — guarded test-only script prepared, not executed.

Reapply: FAIL — one-shot runner prepared, not executed.

Current environment blockers: Supabase CLI, Deno, and psql are unavailable;
Docker Desktop's Linux engine is not running. No independent project
credentials or explicit remote-test deployment approval were used.

Local implementation gates:

- Dart format: PASS, 48 files checked and 0 changed.
- Flutter analyze: PASS with 93 pre-existing non-fatal warnings/information
  findings.
- Flutter tests: PASS, 47/47.
- Contract static checks: PASS, 69/69.
- Secret and dangerous-SQL scans: PASS.
- Dashboard/formal export and delete Function copies: PASS, byte-identical.

## 13. Production Plan

Prepared: YES

Deployment executed: NO

User action required:

1. Install/verify `psql`, Deno, and Supabase CLI.
2. Supply an independent project ref and a distinct production project ref.
3. Supply test-project database/auth values through environment variables
   without printing them.
4. Run the single acceptance command in
   `docs/BACKEND_CONTRACT_ALIGNMENT_PRODUCTION_RUNBOOK.md`.
5. Retain the generated evidence.
6. Return the evidence for review.
7. Request a separate production-deployment approval only after every phase
   passes.

## 14. Deferred

- ActiveTrainingSession cross-device sync
- live Rest Timer sync
- live Superset override sync
- frontend cloud adapters for the new backend entities
- template Superset serialization
- completed-session started/completed timestamps
- Avatar upload
- Health Connect and Apple Health
- notifications and global UI preferences
- Vector DB, embedding service, remote large knowledge base, fine-tuning
- known duplicate `diet_logs` / `exercise_logs` updated_at triggers

## 15. Final Decision

BACKEND_CONTRACT_ALIGNMENT_NOT_READY
