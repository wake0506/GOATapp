# Phase 2A: Nutrition Fast Entry

## Boundary

- Nutrition Feature owns fast diet entry sheets, recent-food suggestions, repeat actions, copy preview, and record editing.
- `main.dart` provides composition, current `viewDateStr`, local-first repository operations, and the existing app state.
- `NutritionQuickAccessService` is pure logic over `ConsumedRecord`; it does not call Supabase, DeepSeek, or platform speech APIs.

## Product decisions

- Text entry and AI preview are the default path.
- System speech remains available only with `--dart-define=ENABLE_SYSTEM_SPEECH=true`.
- Existing speech service and lifecycle tests remain in the codebase; no speech diagnosis is part of this phase.
- Recent suggestions are derived from historical consumed records and do not add a cloud table.
- Copy operations create new record IDs and use the current business date.

## Data safety

- All writes go through `NutritionRepository` and preserve local-first persistence.
- Delete operations continue to use the explicit phase-one pending-delete queue.
- Edit operations retain the original record ID and do not enqueue a delete.
- Copy and repeat operations batch one local save and one best-effort cloud sync.

## Verification

- Pure recent-food normalization, ranking, empty history, copy planning, and new-ID behavior should be covered without real Supabase, DeepSeek, or microphones.
- Widget coverage should assert the quick sheet, recent-food amount confirmation, copy preview, edit validation, and feature-flagged speech visibility.
- Physical microphone validation remains a separate manual task.
