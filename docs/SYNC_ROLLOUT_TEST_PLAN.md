# Versioned Sync Rollout Test Plan

## Scope and enablement

Versioned sync is disabled by default. Normal users continue using the
compatibility snapshot sync path.

Only use a dedicated QA build with the explicit build flag below:

```powershell
flutter run --dart-define=ENABLE_VERSIONED_SYNC=true
```

The flag enables the durable sync queue, `client_operations` audit writes,
tombstones, incremental cursor reads, individual water records, body-weight
logs, and structured `training_sessions` synchronization. Do not use it in a
release distributed to ordinary users until the cases below have passed with
dedicated test accounts.

The server keeps `version` and `updated_at` on the versioned tables. The
current client treats server `updated_at` as the incremental cursor and keeps
the existing last-write-wins compatibility behavior. Same-version concurrent
edits remain diagnostic-only; do not use this rollout as a claim of conflict
free collaborative editing.

## Manual two-device cases

Use two physical devices or two isolated app installs signed into the same
dedicated test account. Record the date, device, and visible result for every
case. Stop the rollout on a data loss or cross-account data issue.

1. Device A adds a diet record. Device B resumes or refreshes and receives it.
2. Device A edits that diet record. Device B receives the changed nutrition and
   meal fields.
3. Device A deletes that diet record. Device B does not restore it after a
   later sync.
4. Device A adds, edits, then deletes an individual water record. Device B
   shows the same total and does not invent a time for legacy aggregate water.
5. Device A changes weight. Device B receives the same two-decimal value.
6. Device A adds an exercise record. Device B receives its type, date, time,
   and calories.
7. Device A records diet, water, weight, and exercise while offline. After
   connectivity returns, each item reaches Device B once.
8. Sign out on Device A, then sign in with another test account. The namespace
   changes and no prior account data is visible.
9. Sign in with different test accounts on A and B. No food, water, weight,
   exercise, or training data crosses account boundaries.
10. Reinstall Device B, sign in again, and confirm cloud data restores without
    creating duplicate records.

## Expected diagnostics

- A failed upload leaves queued operations in the local namespace for retry.
- A successful versioned upload clears only the operations it submitted and
  advances the local cursor after the complete batch succeeds.
- Tombstones are applied before local snapshot deletes are acknowledged.
- Disable the build flag to return to the compatibility path. Do not delete
  tombstones or remote versioned rows during rollback analysis.
