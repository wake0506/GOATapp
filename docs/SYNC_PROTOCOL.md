# Sync Protocol

GOAT remains local-first. A user action updates the in-memory state, saves the namespaced snapshot, and appends durable sync work. Cloud work is best effort and never blocks ordinary local recording.

## Operation

Each `SyncOperation` contains an operation ID, namespace user ID, entity type and ID, `upsert` or `delete` action, payload, creation time, retry count, and next retry time. The operation ID is stable for the same user/entity/action so a retry is idempotent.

Operations are persisted inside the user namespace through `AppSnapshot`. A failure keeps the operation and schedules exponential backoff. App startup, foreground resume, and a later network recovery call the retry path.

## Deletes and conflicts

Deletes create explicit `sync_tombstones` entries. The client does not infer deletion from a difference between a local snapshot and a remote list. Tombstones remain until the cloud operation succeeds.

The current conflict policy is last-write-wins using `version`, then `updated_at`. A remote row with an older version must not overwrite a newer local row. Same-version conflicts are diagnostic-only and remain a known limitation.

## Incremental pull

`SyncCursor` stores the last successfully processed timestamp. Incremental reads use `updated_at > lastSyncedAt` and include tombstones. The cursor advances only after the complete batch is applied. A missing cursor triggers a full recovery pull.

Until the migration is deployed and the remote schema is verified, the Flutter client keeps the phase-one full-snapshot path as the compatibility default. The feature flag for incremental sync must be enabled only after remote rollout verification.
