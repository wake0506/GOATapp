# GOAT Architecture

## Current phase boundaries

- `lib/models/`: serializable domain models shared by pages and persistence.
- `lib/services/`: platform and network boundaries, including namespaced local storage, cloud sync, speech recognition, and nutrition AI.
- `lib/repositories/`: local-first write/read contracts for nutrition and training records.
- `lib/features/voice_entry/`: the voice entry state machine, bottom sheet, editable text, parse preview, and confirm flow.
- `lib/core/`: shared theme, errors, and date utilities as they are extracted.
- `lib/main.dart`: app bootstrap and existing page composition; new business logic must not accumulate here.

## Data flow

User actions write to a namespaced local snapshot first. Cloud synchronization is best effort, bounded by timeouts, and reconciles deletions instead of only upserting current rows. Guest data is isolated from authenticated data and is merged by stable record ID only after a successful authenticated merge.

Voice input follows `idle -> requestingPermission -> initializing -> listening -> finalizing -> recognized -> parsing -> preview -> saving`. The parser returns DTOs; only an explicit confirmation writes records through a repository.

