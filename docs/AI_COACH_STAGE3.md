# Personal AI Coach Stage 3 Foundation

## Scope

Stage 3 adds a local-first personal coach foundation without changing Supabase,
RLS, Edge Functions, production configuration, or the versioned-sync protocol.
The profile entry is under `我的 -> AI 对我的了解`; it is intentionally not a
Home hero card.

The local key is `goat_<user namespace>_ai_coach_v1`. Guest and authenticated
users have separate keys. A sign-in may move the current guest AI state into the
authenticated namespace, while suppression in the target namespace wins.

## Existing AI path audit

| Path | Current behavior | Stage 3 decision |
| --- | --- | --- |
| Nutrition quick/voice parse | Production default uses the authenticated `nutrition-ai` Edge Function | Unchanged and backward compatible |
| Home daily advice | Optional debug-only direct DeepSeek request; failure leaves the existing local tip | Unchanged |
| Training advice card | Existing non-blocking presentation card | Unchanged; deterministic Stage 2 engines remain authoritative |
| Legacy coach chat | Direct provider access is debug-only; authenticated history uses the existing `chat_history` table | Audited but not expanded in this frontend-only stage |
| Stage 3 explanations | Structured gateway contract with deterministic retrieval and safe local fallback | Added; remote gateway alignment deferred |

No provider key, raw app snapshot, complete nutrition history, or complete
set-by-set training history is added to a Stage 3 context.

## Data contract

Memory sources are `userProvided`, `behaviorDerived`, and `aiInferred`.
Inferred memory starts as `pendingConfirmation`; only confirmed active memory is
eligible for context. Rejected, incorrect, and archived stable keys suppress
immediate regeneration.

Suggestions distinguish `accepted` from `applied`. The application sequence is:

`proposed -> user confirmation -> domain validation -> persist -> applied`

Validation or persistence failure produces `applyFailed`; it never reports a
successful application.

## Deterministic engine boundary

These existing results remain authoritative:

- Effective sets
- Trend weight
- Progression recommendation
- Training coverage
- Exercise recommendation
- Rest prescription
- Warm-up recommendation
- Plate calculation

AI is limited to explanation, summary, follow-up answers, and personalized
wording. Explanation response validation removes proposed actions that would
override a deterministic result.

## Knowledge and retrieval

`GoatKnowledgeBaseV1` is a versioned Dart structured asset with stable IDs,
review status, category, source metadata, and short reviewable content. Only
approved entries enter `KnowledgeRetrievalService`; draft and deprecated entries
remain test fixtures for integrity checks.

Retrieval ranks category, task context, tags, reason codes, and stable priority.
Ties are sorted by stable ID, making equal inputs deterministic. No vector
database, embedding API, or remote knowledge store is introduced.

## Context and citation safety

`AiContextAssembler` includes only task-relevant summaries. Rest explanations
receive the current rest recommendation, exercise metadata, current set, and
relevant knowledge. Nutrition explanations do not receive full training set
history.

`AiCoachResponseValidator` accepts only evidence IDs from the assembled data
evidence and knowledge IDs returned by retrieval. Unknown IDs are removed before
display.

## Deferred backend alignment

- AI Memory cross-device sync
- Structured profile sync
- Suggestion history sync
- Feedback analysis/sync
- Remote knowledge store
- Vector RAG and embeddings
- ProgressionTarget backend contract
- RestPrescription backend contract
- Planned/actual rest remote persistence
- Active Session cross-device sync
