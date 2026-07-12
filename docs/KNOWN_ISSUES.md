# Known Issues And Verification

Branch: `refactor/stability-and-voice-entry`

Phase 1 verification is based on the current branch head.

## Environment blockers

- `git pull --ff-only` could not refresh the remote because Windows Schannel returned `SEC_E_NO_CREDENTIALS` while accessing GitHub. The working `main` was already synchronized with the last confirmed `origin/main` state before this branch was created.
- The system PATH still resolves Java 8, while Flutter Android builds use Android Studio's bundled JDK 21. Keep the Flutter JDK selection explicit when diagnosing Android builds.

## Code baseline observed

- `lib/main.dart` contains the domain models, storage, cloud sync, speech plugin access, AI HTTP parsing, and most page code in one file.
- Speech input is long-press based and directly uses `SpeechToText` from page state.
- Shared preference writes are not awaited and use global keys.
- Cloud sync uses an explicit, namespaced `PendingCloudDeletes` queue for food, diet, exercise, and tracking deletions. It never infers deletions from a local snapshot missing rows.
- Training code has direct system-date reads instead of consistently using `viewDateStr`.

This file is updated with command results after the refactor and final quality checks.

## Phase 1 verification update

- Nested generated files under `lib/` were removed because they shadowed the root package configuration. `flutter analyze --no-pub` now resolves Supabase, speech, and permission packages correctly.
- `dart format --output=none --set-exit-if-changed lib test`: passed.
- `flutter test --no-pub`: passed, including model compatibility, namespace migration, parser safety, duplicate request protection, and voice preview/confirm behavior.
- `flutter build web --debug --no-pub`: passed; Web output was generated under `build/web`.
- `flutter analyze --no-pub`: no errors; remaining output is legacy page lint/info such as `withOpacity`, async BuildContext warnings, and unused old page fields.
- Flutter 3.41.6, Dart 3.11.4, Android SDK 36.1.0, and Android Studio JDK 21 were verified.
- `flutter build apk --debug` passed in approximately 99.9 seconds. APK: `build/app/outputs/flutter-apk/app-debug.apk` (156,232,109 bytes).
- `flutter test --no-pub`: passed with 15 tests.
- `flutter analyze --no-pub`: no errors; 83 historical lint/info findings remain and are not treated as this phase's failure.
- `dart format --output=none --set-exit-if-changed lib test`: passed.

## Explicit deletion and migration limits

- Local-first storage and explicit cloud deletion queues are implemented per namespace.
- Concurrent edits across devices do not yet have an `updated_at` conflict-resolution policy.
- Before production launch, add server-side versioning, timestamps, or soft-delete tombstones for robust multi-device conflict handling.
- Guest migration is guarded by persisted namespaces and clears the guest namespace only after the authenticated upload succeeds. A failed upload leaves guest data and the authenticated merged snapshot available for retry.
- Training data remains an atomic `user_profiles.training_data` JSON payload. Deleting a training session or exercise set persists the updated payload; separate server-side training tombstones are not used in this phase.
- DeepSeek keys are supplied only through `--dart-define`; no local key is documented or committed.
- Debug APK size is not a release APK size guarantee.

## Speech recognition verification status

- The speech service now uses an incrementing session ID and ignores callbacks from stale or cancelled sessions.
- `SpeechState.listening` is emitted only after the platform reports raw `listening`; the return of `speech.listen()` is not treated as confirmation.
- Premature `notListening`/`done` during startup becomes an error and never becomes an empty successful recognition.
- Debug builds log session ID, elapsed time, raw status, raw error code/permanence, final-result status, partial-text presence, sound-level receipt, and stop/cancel intent without logging full food text.
- Voice sessions use dictation mode, a five-second pause window, and a thirty-second maximum window; no automatic retry loop is used.
- Fake speech-engine tests cover premature terminal status, platform listening confirmation, partial fallback, manual stop, stale callbacks, and concurrent starts.
- Physical Android and browser microphone verification remains pending because no real device is currently available. Passing unit/widget tests do not prove microphone hardware behavior.
