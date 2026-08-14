# NexFit — Two-Way Sync Architecture

> PROMPT 10 foundation deliverable (Part 21). Describes the implemented offline-first
> two-way sync foundation built on top of the existing `SyncEngine`/`SyncTransport`/
> `SyncEventRecorder` stack. Local schema: **SQFlite v15**. Cloud: Supabase
> (`supabase/migrations/001_initial_nexfit_schema.sql`), unchanged.

## 1. Shape of the pipeline

```
                   ┌─────────────────────────── local device ───────────────────────────┐
  DAO writes ──▶ SyncEventRecorder ──▶ sync_event (outbox)                              │
                                                                                        │
                       SyncEngine.sync(userId) under per-user SyncLock                  │
        ┌───────────────────────────────────────────────┐                               │
        │ 1) PUSH outbox (processQueue)                 │                               │
        │    RetryScheduler backoff, markProcessing/    │                               │
        │    markSuccess/mark*Failure, conflict detect  │                               │
        │ 2) PULL sync_changes by cursor (pull)         │                               │
        │    batches applied + cursor advanced in the   │                               │
        │    SAME transaction (RemoteChangeApplier)     │                               │
        └───────────────────────────────────────────────┘                               │
                                                                                        │
   SupabaseSyncTransport ──▶ supabase_sync_client ──▶ Supabase (sync_changes, rows)     │
   SyncStateRepository ──▶ sync_state (local cursor per user)                           │
                                                                                        │
  UI ──▶ SyncStatusController / syncStatusProvider (SyncUiStatus) ──▶ status banner     │
   └────────────────────────────────────────────────────────────────────────────────────┘
```

The ordering is deliberately **push-then-pull**: this device's newest writes land on
the cloud before it reads remote rows, so a concurrent change made on another device
is picked up on the very next sync without waiting for a second cycle.

## 2. Outbox (local `sync_event`)

- Every `USER_SYNCABLE` DAO write that is recorded (only **7 of 31** tables today — see
  `NEXFIT_DAO_SYNC_MIGRATION_PLAN.md`) calls `SyncEventRecorder.record(...)`.
- `record()` builds a stable v1 envelope (`SyncEventPayload`, `schema_version: 1`) and
  inserts an outbox row with:
  - `event_uuid` — UUID v4 generated **once** per logical mutation (preserved across
    retries and when a duplicate upsert is detected), used as the idempotency key.
  - `device_id` — device identity from `DeviceIdService` (UUID v4, stored in secure
    storage), stamped by `SessionManager.getOrCreateDeviceId()`.
  - `base_version` — local `row_version` of the row being written; used by the cloud
    conditional update for conflict detection.
  - `status` ∈ `pending | processing | completed | failedRetryable | failedPermanent`
    (`failed` remains as a legacy alias mapped to `failedPermanent` on read so old rows
    keep working).
  - `next_retry_at` — when the event may be retried (backoff gate).
- Transactional outbox: `SyncEventRecorder.recordInTransaction(txn, ...)` and
  `SyncEventRepository.insertInTransaction(txn, event)` allow a DAO mutation and its
  outbox row to commit atomically (Part 5). Non-transactional `record()` is also
  supported for DAOs that are not yet converted.

## 3. Push path (`SyncEngine.processQueue` → `_processQueueUnlocked`)

1. `resetStuckProcessingEvents` reclaims rows stuck in `processing` older than
   `syncStuckProcessingTimeout` (5 min) back to `pending`.
2. Page through `getRetryableByUserId` (status `pending` or `failedRetryable` AND
   `next_retry_at <= now`), capped by `syncQueuePageSize`.
3. For each event:
   - Mark `processing`, build the payload, and call `transport.push(userId, payload)`.
   - **Idempotency without a schema change:** the cloud row key equals the local event
     row's `id`; every push is `upsert(...).onConflict('id')`. Retrying a previously
     applied event can never duplicate a row. No Supabase migration was required.
   - **Conflict detection:** `SupabaseSyncTransport` pushes `row_version = base_version`
     and updates via `.update(row).eq('id', uuid).eq('row_version', base_version)`. An
     empty result means a concurrent device changed the row first ⇒
     `SyncPushResult(conflict: true)`.
   - Resolution (engine, per event `conflict_strategy`):
     - `latestWins` — the event is marked `completed`; the local row will be reconciled
       by the following pull. Counted in `SyncRunResult.conflicts`.
     - `manualMerge` — the event stays `pending` with
       `lastError = 'manual_merge_required'` so the user can intervene. Counted in
       `conflicts`.
   - Non-conflict errors: transient ⇒ `failedRetryable` with `nextRetryAt` from
     `RetryScheduler` backoff (2/5/15/30/60/120/300 s, capped); permanent ⇒
     `failedPermanent` (counted, never retried).

## 4. Pull path (`SyncEngine.pull` → `_pullUnlocked`)

- Cursor state lives in a new local `sync_state` table (per user: `cursor`,
  `last_sync_at`, `initial_sync_completed`, `status`).
- `transport.pull(userId, cursor, limit)` reads `sync_changes` rows `> cursor`,
  ordered ascending, capped at `syncPullBatchSize`; `nextCursor` is the last applied
  change id.
- Each batch is applied by `RemoteChangeApplier` **inside one transaction together with
  the cursor advance** (`upsertInTransaction`). A failure (e.g. an unmapped cloud table)
  rolls back both the rows and the cursor, so the cursor never moves past unapplied
  changes (Part 11). Cursors are per user (Part 12).
- Loop until the batch reports `hasMore == false` or `syncMaxPullBatches` is reached.
- The initial sync run marks `initialSyncCompleted = true`; a `sync_state` row with no
  cursor starts at `syncInitialCursor = 0`.
- **Loop prevention (Part 16):** `RemoteChangeApplier` writes pulled rows directly
  (`APPLY_SOURCE_REMOTE`) and **never enqueues outbox events**, so a pull can never
  feed the push queue. Cloud writes that go through the app's own push are still
  recorded in `sync_changes` by the cloud trigger; this is accepted and harmless
  because applier writes are idempotent upserts keyed on the same UUID.
- Delete changes apply a soft-delete tombstone (`deleted_at`) on the local row when the
  table supports it; `profiles` (which has no tombstone) is treated as a no-op.
- Unmapped cloud tables raise `UnsupportedTableException`; the batch transaction rolls
  back and `SyncEngine.sync` reports a partial failure without aborting the app.

## 5. Engine orchestration (`SyncEngine.sync`)

1. Acquire the per-user `SyncLock` (single-flight; concurrent runs for the same user
   cannot overlap).
2. `_processQueueUnlocked` — push path (above).
3. `_pullUnlocked` — pull path (above).
4. `SyncTransportException`/`UnsupportedTableException` from the pull are converted to a
   partial-failure result (`failed + 1`, `hasPulled: false`) — the user's push already
   succeeded.
5. `SyncRunResult` reports `processed/succeeded/failed/conflicts/pulled/hasPulled`;
   `SyncEngine.snapshot(userId)` aggregates queue stats for the status provider.

The engine uses unlocked internals (`_processQueueUnlocked`/`_pullUnlocked`) so `sync()`
holds the lock exactly once and never nests `synchronized` (no deadlock).

## 6. Transport contract (`SyncTransport` in `sync_contracts.dart`)

- `name`, `isReady`, `push(userId, SyncEventPayload) → SyncPushResult`, and
  `pull(userId, cursor, limit) → SyncPullBatch`.
- `SupabaseSyncTransport` is the production implementation (auth via
  `_requireUserId`, `service`/`database` exposed for the migration path). Push/pull are
  tested through fake transports in `test/`; the real Supabase transport compiles but is
  not integration-tested in this environment.

## 7. Status surface for the UI

- `SyncUiStatus` enum: `idle / syncing / success / offline / partialFailure / error /
  conflict` (name chosen because `SyncStatus` is already the event-lifecycle enum).
- `SyncStatusController` + `syncStatusProvider` in `sync_providers.dart` publish a
  `SyncStatusSnapshot`; `SyncController.refresh()` calls
  `resetStuckProcessingEvents` so a previous crash cannot wedge the queue forever.

## 8. Files created / modified

Created:
- `lib/core/security/uuid_generator.dart`
- `lib/data/services/security/device_id_service.dart`
- `lib/data/services/sync/sync_event_payload.dart`
- `lib/data/services/sync/sync_contracts.dart`
- `lib/data/services/sync/supabase_sync_transport.dart`
- `lib/data/services/sync/sync_table_registry.dart`
- `lib/data/services/sync/remote_change_applier.dart`
- `lib/data/services/sync/sync_log.dart`
- `lib/domain/entities/sync_state.dart`
- `lib/data/models/sync_state_model.dart`
- `lib/data/datasources/local/sync_state_local_data_source.dart`
- `lib/domain/repositories/sync_state_repository.dart`
- `lib/data/repositories/sync_state_repository_impl.dart`
- `test/sync_foundation_test.dart`

Modified: `sync_engine.dart`, `sync_event_recorder.dart`, `sync_event_local_data_source.dart`,
`sync_event_repository.dart` (+ impl), `sync_event.dart`/`sync_event_model.dart`,
`security_enums.dart`, `app_constants.dart`, `session_manager.dart`, `dependency_injection.dart`,
`splash_screen.dart`, `sync_providers.dart`, `app_database.dart` (migration v15),
`test/sync_engine_test.dart`.

## 9. Deliberate non-goals (this phase)

- No DAO mass-migration (only the foundation exists — see the migration plan).
- No production bulk sync.
- No Supabase schema changes (idempotency needed none; documented above).
- No local data deletion anywhere.
