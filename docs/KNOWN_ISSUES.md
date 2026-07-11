# Known Issues And Baseline

Baseline branch: `refactor/stability-and-voice-entry`

Baseline commit: `ff57304` (`Update GOAT app statistics and exercise catalog`)

## Environment blockers

- `git pull --ff-only` could not refresh the remote because Windows Schannel returned `SEC_E_NO_CREDENTIALS` while accessing GitHub. The working `main` was already synchronized with the last confirmed `origin/main` state before this branch was created.
- `flutter pub get` and the offline variant both stalled during the Flutter tool startup/dependency phase with no output. `dart format` and `flutter --version` showed the same startup stall. A stale Flutter cache lock or local toolchain process must be checked before treating those commands as code failures.

## Code baseline observed

- `lib/main.dart` contains the domain models, storage, cloud sync, speech plugin access, AI HTTP parsing, and most page code in one file.
- Speech input is long-press based and directly uses `SpeechToText` from page state.
- Shared preference writes are not awaited and use global keys.
- Cloud sync upserts current records but does not reconcile deleted food, diet, exercise, or tracking rows.
- Training code has direct system-date reads instead of consistently using `viewDateStr`.

This file is updated with command results after the refactor and final quality checks.

