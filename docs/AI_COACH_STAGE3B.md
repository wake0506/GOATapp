# AI Coach Stage 3B

Stage 3B connects the local-first coach foundation to real nutrition, training,
rest, coverage, and weekly-review surfaces.

## Authority boundary

The deterministic calculators remain authoritative:

1. A domain engine produces a structured result.
2. `AiCoachScenarioService` selects only task-relevant facts.
3. `KnowledgeRetrievalService` retrieves approved local knowledge.
4. The coach creates an explanation without replacing the engine action.
5. `AiCoachResponseValidator` removes unknown evidence and knowledge refs.
6. A proposed action requires a user preview and confirmation.
7. A domain service validates and persists the action.
8. Suggestion transitions and feedback are stored in the active namespace.

An explanation failure never hides the deterministic recommendation.

## Scenario integrations

- Home: weekly nutrition completeness, macro averages, goal, trend weight,
  preferences, and relevant confirmed memories.
- Progression: the exact engine action, reliable recent performance, reason
  codes, data quality, RIR, and failure context.
- Rest: the exact recommended, planned, base, and modifier seconds plus rest
  class, set type, RIR, failure, fixed, and session-override state.
- Coverage: the current coverage result and catalog candidate already selected
  by `ExerciseRecommendationEngine`.
- Weekly review: structured training, nutrition, weight, and coverage facts,
  followed by no more than three short suggestions.

The UI uses shared evidence, preset follow-up, fallback, and action-confirmation
surfaces. It does not introduce an unrestricted chat page.

## Suggestion lifecycle

Normal flow:

`proposed -> accepted -> applied`

Edited flow:

`proposed -> modified -> accepted -> applied`

Validation or persistence failures end as `applyFailed`. Rejected and dismissed
suggestions are retained, and feedback distinguishes helpful, not-for-me,
inaccurate-data, disliked, and dismissed responses.

Template updates never mutate the snapshot of an active training session.

## Deferred backend alignment

Stage 3B does not change Supabase, RLS, Edge Functions, migrations, or sync
protocols. The following remain deferred:

- AI scenario history sync
- suggestion sync
- feedback sync
- memory sync
- remote knowledge store
- vector RAG
- general coach AI endpoint
- progression target sync
- rest prescription sync
