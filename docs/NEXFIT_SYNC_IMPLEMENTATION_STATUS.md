# NexFit — Sync Implementation Status

> PROMPT 10 deliverable (Part 21). Companion to `NEXFIT_TWO_WAY_SYNC_ARCHITECTURE.md`.
> Each row maps a prompt part to its implementation state and test evidence.

## 1. Implementation summary

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | Extend `SyncStatus` with `processing`, `failedRetryable`, `failedPermanent`; keep `failed` as legacy alias | Done | `lib/domain/entities/security_enums.dart`; `fromName('failed') → failedPermanent` |
| 2 | Device identity (UUID v4, persisted, no PII) | Done | `UuidGenerator`, `DeviceIdService`, `SessionManager.getOrCreateDeviceId()` delegates |
| 3 | Outbox: `event_uuid`, `device_id`, `base_version`, `next_retry_at` on `sync_event` (migration v15) | Done | `app_database.dart` v15 + `app_database_migration_v15_test.dart` (16 green) |
| 4 | Outbox data source: `markProcessing`, `markSuccess`, `markRetryableFailure`, `markPermanentFailure`, `resetStuckProcessingEvents`, `getRetryableByUserId`, counts | Done | `sync_foundation_test.dart` (outbox data source group, 4 green) |
| 5 | Transactional outbox: `recordInTransaction` / `insertInTransaction` atomic commit + rollback | Done | `sync_foundation_test.dart` (transactional outbox, 2 green) |
| 6 | `SyncEventPayload` v1 envelope | Done | `sync_foundation_test.dart` (payload contract, 2 green) |
| 7 | `SyncPushResult` (applied/conflict/error) | Done | `sync_contracts.dart`; used by `sync_engine_test.dart` conflicts |
| 8 | Idempotent cloud upsert without schema change | Done | `SupabaseSyncTransport` `upsert(...).onConflict('id')`; documented in architecture §3 |
| 9 | Conflict detection via `row_version` conditional update | Done | `supabase_sync_transport.dart`; engine resolves `latestWins`/`manualMerge` |
| 10 | `sync_state` table + repo (cursor persistence) | Done | `app_database.dart` v15; `sync_state` stack + tests |
| 11 | Cursor + applied rows advance in one transaction | Done | `SyncEngine._applyBatch`; rollback test green |
| 12 | Per-user cursor isolation | Done | `sync_foundation_test.dart` (cursor scoped per user) |
| 13 | Initial sync marker (`initial_sync_completed`) | Done | `_pullUnlocked` sets it after first successful run |
| 14 | Incremental pull loop capped by `syncMaxPullBatches` | Done | `_pullUnlocked`; constant in `app_constants.dart` |
| 15 | Respect auth/network/retries/status/conflicts | Done | `SyncRunResult`, `RetryScheduler`, partial-failure on pull error |
| 16 | Loop prevention: remote apply never enqueues outbox events | Done | `RemoteChangeApplier`; test green |
| 17 | `RetryScheduler` backoff 2/5/15/30/60/120/300 | Done | `sync_foundation_test.dart` (scheduler test green) |
| 18 | Status counting in `snapshot()` | Done | `SyncEngine.snapshot` aggregates pending/failed |
| 19 | `SyncUiStatus` provider + `SyncStatusController` | Done | `sync_providers.dart`; `refresh()` resets stuck events |
| 20 | Structured logging (start/push/pull/conflict/complete) | Done | `sync_log.dart`; masked UUIDs/errors |
| 21 | Docs (this file + architecture + migration plan) | Done | `docs/` |

## 2. Test evidence

| Suite | Result |
|---|---|
| `flutter analyze` (lib + test) | Clean — "No issues found!" |
| `test/sync_engine_test.dart` | 9/9 green (uuid, duplicate-preserves-uuid, backoff gate, stuck reclaim, permanent failure, latestWins/manualMerge conflicts, full cycle) |
| `test/sync_foundation_test.dart` | 21/21 green (device id, uuid, payload, scheduler, outbox SQL, transactional outbox, recorder identity, pull/cursor/remote-apply, engine orchestration) |
| `test/app_database_migration_v15_test.dart` | 16/16 green (data preserved, indexes, row_version default) |
| `test/master_data_sync_test.dart` | 16/16 green (PROMPT 16 — master-data download; see `NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §12) |
| `test/incremental_sync_test.dart` | 14/14 green (PROMPT 18 — incremental sync + realtime notification; see `NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §13) |
| `test/initial_sync_test.dart` | 14/14 green (PROMPT 17 — initial user sync, local-data ownership + opt-in adoption; see `NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §14) |
| `test/conflict_resolution_test.dart` | 11/11 green (PROMPT 19 — durable conflict store + migration v17, SERVER_WINS default, local data preserved, delete-vs-update, repeated/resolved conflicts, pending-conflict UI count; see `NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §15) |
| `test/large_dataset_sync_test.dart` | 5/5 green (PROMPT 20 — WAL/PRAGMA, pagination, EXPLAIN QUERY PLAN, bounded incremental cap, 10,001-record benchmark; see `NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §16) |
| `test/sync_failure_recovery_test.dart` | 15/15 green (PROMPT 21 — 12 failure scenarios + startup recovery; see `NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §17) |
| `test/sync_status_ux_test.dart` | 13/13 green (PROMPT 22 — status chip mapping, derived status per state, chip labels, compact variant, "Sync now" concurrency guard, offline completion path, friendly failure path; see `NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §18) |
| `test/multi_device_sync_test.dart` | 8/8 green (PROMPT 23 — two logical devices on separate SQLite DBs; workout create/update, offline food log, SERVER_WINS conflict, delete tombstone, 100 offline records uploaded exactly once, 1000 remote changes incremental cursor, kill-and-restart recovery; see `docs/NEXFIT_MULTI_DEVICE_SYNC_TEST.md`) |
| `test/sync_security_audit_test.dart` | 10/10 green (PROMPT 24 — two-user cross-user read/write/update/delete isolation, `sync_state` local-only, master read-only, no service-role key, no PII columns, no passwords in payloads, no token/secret logging; see `docs/NEXFIT_SYNC_SECURITY_AUDIT.md`) |
| `test/offline_first_e2e_test.dart` | 3/3 green (PROMPT 25 — offline-first journey through seven real DAOs: offline reads reflect create/edit/delete immediately, offline sync uploads nothing, reconnect converges a second device, flapping push-succeeds/pull-fails run recovers without duplicates; see `docs/NEXFIT_OFFLINE_FIRST_E2E_TEST.md`) |
| Full regression | **437 pass / 2 fail** — both pre-existing and unrelated |
| `test/hydration_repository_test.dart` | 1 pre-existing unrelated failure unchanged: `loadStatistics computes averages, best day and streaks` — Expected `<2>` Actual `<0>`. Not introduced by this work; left untouched. |

## 3. What is NOT yet done (by design)

- DAO conversion (only the foundation; 25/48 tables are sync-registered and
  record events — 13+ user tables remain). See `NEXFIT_DAO_SYNC_MIGRATION_PLAN.md`.
- Live Supabase integration testing of `SupabaseSyncTransport` (no cloud
  credentials here; push/pull verified against fake transports in tests).
- Server-side provisioning: RLS policies, the `sync_changes` feed and per-user
  Realtime are assumed, not verifiable from this repo (see
  `NEXFIT_PRODUCTION_READINESS.md`).
- Offline-first E2E audit (PROMPT 25) is complete — see `NEXFIT_OFFLINE_FIRST_E2E_TEST.md`.
- Sync security audit (PROMPT 24) is complete — see `NEXFIT_SYNC_SECURITY_AUDIT.md`.
- Production readiness audit (PROMPT 26) is complete — see
  `NEXFIT_PRODUCTION_READINESS.md`: the sync core is ready; go-live requires a
  staging Supabase smoke suite + server-side RLS / `sync_changes` / Realtime
  provisioning, and 13+ user tables remain to be DAO-migrated.

## 4. Constants introduced

`lib/core/constants/app_constants.dart`:
`syncStuckProcessingTimeout` (5 min), `syncRetryBackoffSeconds` (2,5,15,30,60,120,300),
`syncMaxPullBatches` (50), `syncPullBatchSize` (100), `syncLogMaxEventUuidChars` (12),
`syncQueuePageSize` (500), `syncInitialCursor` (0).
