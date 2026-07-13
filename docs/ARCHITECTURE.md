# GOAT Architecture

## Current phase boundaries

- `lib/models/`: serializable domain models shared by pages and persistence.
- `lib/services/`: platform and network boundaries, including namespaced local storage, cloud sync, speech recognition, and nutrition AI.
- `lib/repositories/`: local-first write/read contracts for nutrition and training records.
- `lib/features/voice_entry/`: the voice entry state machine, bottom sheet, editable text, parse preview, and confirm flow.
- `lib/features/nutrition/`: text-first fast diet entry, recent-food access, repeat/copy preview, and record editing.
- `lib/core/`: shared theme, errors, and date utilities as they are extracted.
- `lib/main.dart`: app bootstrap and existing page composition; new business logic must not accumulate here.

## Data flow

User actions write to a namespaced local snapshot first. Cloud synchronization is best effort, bounded by timeouts, and upserts current rows plus only the IDs and dates in the persisted `PendingCloudDeletes` queue. A queue entry is removed only after the corresponding cloud delete succeeds; an empty or incomplete snapshot never implies deletion. Guest data is isolated from authenticated data and is cleared only after the merged authenticated snapshot uploads successfully.

Voice input follows `idle -> requestingPermission -> initializing -> listening -> finalizing -> recognized -> parsing -> preview -> saving`. The parser returns DTOs; only an explicit confirmation writes records through a repository.

Phase 2A nutrition entry follows `quick add -> recent/repeat/text -> preview -> confirm -> repository`. System speech is opt-in through `ENABLE_SYSTEM_SPEECH=true`; the default path remains text-first and does not depend on a microphone or DeepSeek availability for ordinary historical/repeat actions.
