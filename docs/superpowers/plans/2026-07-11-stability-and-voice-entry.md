# Stability And Voice Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use task-by-task checkpoints and run the focused tests after each boundary.

**Goal:** Stabilize the local-first Flutter app and add an editable, preview-before-save Chinese voice diet entry flow without changing the existing visual language.

**Architecture:** Extract serializable models first, then add namespaced local storage and cloud reconciliation services. Put speech plugin access behind a testable stateful service and route all voice entry callers through one bottom sheet. AI parsing returns validated DTOs and repositories receive writes only after confirmation.

**Tech Stack:** Flutter, Dart, `speech_to_text`, `permission_handler`, `SharedPreferences`, Supabase, `http`, Flutter widget/unit tests.

---

### Task 1: Documentation and baseline

- [x] Create project rules and product, UI, architecture, and known-issues documents.
- [ ] Rerun all Flutter quality commands after repairing the local toolchain lock.

### Task 2: Domain models and date utilities

- [ ] Move the seven serializable models from `lib/main.dart` into `lib/models/` without changing JSON keys.
- [ ] Add a single date utility that honors `resetHour` and use it for training, diet, exercise, and history writes.

### Task 3: Local-first storage and cloud reconciliation

- [ ] Add a `LocalStorageService` with guest and user namespaces, one-time legacy migration, explicit keys, and awaited writes.
- [ ] Add snapshot merge-by-ID logic for guest-to-user login and clear the guest namespace only after a successful merge.
- [ ] Add `CloudSyncService` to upsert current rows and delete remote rows missing from the local snapshot.
- [ ] Keep local writes successful when cloud sync fails and expose retryable sync status.

### Task 4: Lifecycle and speech boundary

- [ ] Add `SpeechRecognitionService` and `DeviceSpeechRecognitionService` with explicit states, one-time initialization, Chinese locale selection, final-result waiting, cancellation, and resource disposal.
- [ ] Replace long-press voice interaction with single-tap start/stop and lifecycle cancellation.
- [ ] Add controllers, timers, and callback mounted guards where the refactor touches existing pages.

### Task 5: Voice diet entry V1

- [ ] Add `ParsedDietItem`, `NutritionAiService`, safe JSON parsing, duplicate-request protection, and bounded HTTP calls.
- [ ] Add one reusable voice entry bottom sheet with editable recognition text, parse preview, editable item rows, delete/reparse actions, and confirm-only repository writes.
- [ ] Route the home microphone and all meal entry points through the same sheet and pass the meal type as its default.

### Task 6: Tests and final quality checks

- [ ] Add unit tests for legacy JSON, namespaces, merge de-duplication, parser variants, numeric coercion, duplicate submit protection, locale selection, and state transitions.
- [ ] Add widget tests for the voice sheet and confirm-only save behavior.
- [ ] Run format, analyze, tests, debug APK build, and optional release APK build; record exact results and remaining manual Android checks.

