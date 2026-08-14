# NexFit — Sync Production Readiness Audit

> PROMPT 26 deliverable. A code-review + evidence-based readiness assessment of
> the offline-first two-way sync system for shipping to production. Every
> verdict is backed by a test suite, a static check or a documented constant.
> Companion to `NEXFIT_TWO_WAY_SYNC_ARCHITECTURE.md`,
> `NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` and `NEXFIT_SYNC_IMPLEMENTATION_STATUS.md`.

## 1. Scope and method

Audited against six production criteria — correctness, durability & crash
recovery, performance & scale, security & multi-tenancy, observability, and
operational readiness. Evidence comes from the 20 sync test suites (as of
PROMPT 25: **437 pass / 2 pre-existing unrelated failures**), the two audit
suites (PROMPTS 24–25), static source checks, and the documented constants and
schema (`app_constants.dart`, `app_database.dart`).

## 2. Readiness summary

| Criterion | Verdict | Key evidence |
|---|---|---|
| Correctness & consistency | **Ready** | outbox atomicity, optimistic `row_version` conflicts, tombstones, per-user cursors, exactly-once uploads, idempotent upserts |
| Durability & crash recovery | **Ready** | transactional outbox, WAL + `synchronous=NORMAL`, stuck-processing reclaim, retry backoff, kill-and-restart recovery |
| Performance & scale | **Ready** | WAL/cache/mmap PRAGMAs, batched DAO writes, bounded incremental pulls, 10,001-record benchmark, 1000-remote incremental pull |
| Security & multi-tenancy | **Ready with server dependency** | PROMPT 24 audit: cross-user isolation enforced client-side + **RLS must exist server-side**; anon key only; no PII/passwords/tokens in payloads or logs |
| Observability | **Ready** | structured masked logging; friendly status surface; durable last-error masking |
| Operational readiness | **Conditional** | no live-Supabase integration test (no credentials here); RLS policies + Realtime must be provisioned; 13+ user tables not yet DAO-migrated |

## 3. Correctness & consistency

- Every tracked mutation commits atomically with its outbox event
  (`SyncableDao` → `SyncEventRecorder.recordInTransaction`); a failing mutation
  rolls back both row and event (verified per batch: `dao_sync_batch1`–`5`).
- Push is idempotent (`onConflict: 'id'` upsert keyed on the record uuid);
  optimistic writes use `row_version`; conflicts resolve `latestWins`
  (SERVER_WINS) or `manualMerge` with a durable conflict record
  (`test/conflict_resolution_test.dart`, 11/11).
- Pull is keyset-paginated with a per-user cursor that advances in the same
  transaction as the applied rows; remote apply never enqueues outbound events
  (`test/sync_foundation_test.dart`, `test/incremental_sync_test.dart`).
- Exactly-once uploads across 100 offline records and no duplicate cloud rows
  after a committed-but-timed-out push (`test/multi_device_sync_test.dart`, 8/8).

## 4. Durability & crash recovery

- `PRAGMA foreign_keys = ON`; native builds run `journal_mode = WAL`,
  `synchronous = NORMAL`, `temp_store = MEMORY`, `cache_size = -8000`,
  `mmap_size = 268435456` (app_database.dart:96–120).
- `resetStuckProcessingEvents` reclaims events stuck in `processing` after
  `syncStuckProcessingTimeout` (5 min); `syncRetryBackoffSeconds` =
  2/5/15/30/60/120/300; `syncEventMaxRetries = 3` before permanent failure;
  completed events pruned after `syncEventRetention` (14 days).
- Kill-and-restart: a push that committed then timed out is recovered without a
  duplicate cloud row (`multi_device_sync_test` #8); 12 failure scenarios +
  startup recovery (`test/sync_failure_recovery_test.dart`, 15/15).

## 5. Performance & scale

- WAL + memory PRAGMAs keep offline writes fast; DAO bulk writes use single
  batched transactions (1500-row weight history, one transaction).
- Pull is capped at `syncMaxPullBatches` (50) × `syncPullBatchSize` (100);
  1000 remote changes pull incrementally with a stable cursor
  (`multi_device_sync_test` #7).
- 10,001-record benchmark + `EXPLAIN QUERY PLAN` verification
  (`test/large_dataset_sync_test.dart`, 5/5).

## 6. Security & multi-tenancy

- PROMPT 24 audit (`docs/NEXFIT_SYNC_SECURITY_AUDIT.md`, 10/10): cross-user
  read/write/update/delete isolation with two test users; `sync_state`
  local-only; master data read-only; no service-role key in the Flutter app
  (anon/publishable only); no PII columns in sync mappings; no passwords in
  payloads; no full uuids/tokens/secrets in logs (`SyncLog` truncation +
  `ValueMasker`).
- **Server dependency:** Postgres RLS is assumed authoritative. The client
  enforces the same boundaries, but RLS policies must exist on every synced
  table (row `user_id = auth.uid()`) or a leaked anon key would expose data.
  Realtime channels must be scoped per user for incremental notifications.

## 7. Observability

- Structured masked logs (`SyncLog`): start/push/pull/conflict/complete markers;
  event uuids truncated to `syncLogMaxEventUuidChars` (12); errors masked.
- UI status surface (`test/sync_status_ux_test.dart`, 13/13): derived
  synced/syncing/offline/failed/conflict/pending statuses, no technical text in
  the widget tree, concurrency-guarded "Sync now".

## 8. Operational readiness — remaining gaps and risks

| # | Gap / risk | Severity | Required before go-live |
|---|---|---|---|
| G1 | **No live-Supabase integration test** — `SupabaseSyncTransport` and `SupabaseMasterDataTransport` are only verified against fake transports (no cloud credentials in this repo) | **High** | Run a credential-backed smoke suite (push/pull/conflict/realtime) against a staging project |
| G2 | **RLS policies not verifiable from here** — security depends on server-side policies existing | **High** | Ship the SQL migration that creates RLS + the `sync_changes` feed (triggers/table), scope Realtime per user |
| G3 | **13+ user tables not yet DAO-migrated** (calorie_log, achievement, badge, streak, daily_progress, workout_template, workout_template_exercise, achievement_def, badge_def, challenge_def, challenge, milestone) | **Medium** | Continue the DAO migration batches; unmapped entities surface as `unsupported_entity` today (fail-safe, not silent) |
| G4 | **Master catalogs** (workout_category, meal_category) and non-user infra (sessions, backups, error_logs) intentionally out of scope | Low | Confirm nothing user-owned depends on them syncing |
| G5 | **Production bulk backfill** of historical rows is not implemented | Medium | Use the initial-sync flow; existing local rows adopt via the opt-in path (`initial_sync_test.dart`, 14/14) |
| G6 | **Two pre-existing unrelated test failures** (`session_manager` device-change, `hydration_repository` loadStatistics) | Low | Fix or re-baseline in a separate track before CI gating |

## 9. Go / no-go recommendation

**Conditional go for the sync foundation.** The client-side sync core is
production-ready and proven (correctness, durability, performance, security and
observability all verified). Do not ship without resolving **G1 and G2**: a
staging Supabase smoke suite plus the RLS / `sync_changes` / Realtime server
migration. G3–G5 are scope decisions, not blockers; G6 is unrelated legacy debt.

## 10. Test evidence snapshot (PROMPTS 10–26)

`flutter analyze` — clean. Full regression after PROMPT 25: **437 pass / 2 fail**
(both pre-existing and unrelated). Audit suites: `sync_security_audit_test.dart`
10/10, `offline_first_e2e_test.dart` 3/3. See
`NEXFIT_SYNC_IMPLEMENTATION_STATUS.md` for the per-suite table.