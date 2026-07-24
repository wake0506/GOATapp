# GOAT Architecture

## Current phase boundaries

- `lib/models/`: serializable domain models shared by pages and persistence.
- `lib/services/`: platform and network boundaries, including namespaced local storage, cloud sync, speech recognition, and nutrition AI.
- `lib/repositories/`: local-first write/read contracts for nutrition and training records.
- `lib/features/voice_entry/`: the voice entry state machine, bottom sheet, editable text, parse preview, and confirm flow.
- `lib/features/nutrition/`: text-first fast diet entry, recent-food access, repeat/copy preview, and record editing.
- `lib/models/sync_operation.dart` and `lib/models/sync_cursor.dart`: durable local sync protocol values.
- `lib/services/sync_queue_service.dart`: namespace-scoped queue and retry policy.
- `lib/core/`: shared theme, errors, and date utilities as they are extracted.
- `lib/main.dart`: app bootstrap and existing page composition; new business logic must not accumulate here.

## Data flow

User actions write to a namespaced local snapshot first. Authenticated writes also append durable `SyncOperation` values to the same namespace. Cloud synchronization is best effort, bounded by timeouts, and keeps failed operations with exponential backoff. The compatibility path upserts current rows plus only the IDs and dates in the persisted `PendingCloudDeletes` queue; the versioned path adds tombstones and detail-table mappings behind an explicit flag. Guest data is isolated from authenticated data and is cleared only after the merged authenticated snapshot uploads successfully.

Voice input follows `idle -> requestingPermission -> initializing -> listening -> finalizing -> recognized -> parsing -> preview -> saving`. The parser returns DTOs; only an explicit confirmation writes records through a repository.

Phase 2A nutrition entry follows `quick add -> recent/repeat/text -> preview -> confirm -> repository`. System speech is opt-in through `ENABLE_SYSTEM_SPEECH=true`; the default path remains text-first and does not depend on a microphone or DeepSeek availability for ordinary historical/repeat actions.

Phase 3A keeps the existing UI frozen and adds an additive Supabase schema, explicit RLS, durable sync operations, tombstones, and an Edge Function boundary for production nutrition AI. Remote deployment is a manual confirmation step.

Stage 3 Personal AI Coach is local-first and additive. `lib/features/ai_coach/`
owns namespaced profile memory, deterministic behavior summaries, structured
suggestion state, the curated knowledge base, deterministic retrieval, minimal
context assembly, structured response parsing, citation validation, and safe
failure fallback. AI receives frozen engine outputs as evidence and may explain
them, but it does not recalculate or directly mutate progression, coverage,
exercise selection, rest, warm-up, plate, trend-weight, or effective-set
results. A proposed action can reach a domain service only after explicit user
confirmation and is marked `applied` only after validation and persistence
succeed.
