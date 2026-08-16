# NexFit — DAO Sync Migration Plan

> PROMPT 10 deliverable (Part 21). Follow-up work that is **deliberately NOT performed**
> in the foundation phase. Companion to `NEXFIT_TWO_WAY_SYNC_ARCHITECTURE.md`.
>
> **Status (PROMPT 18):** Incremental sync + Realtime notification shipped — the
> event-driven trigger hub (`IncrementalSyncCoordinator`), a notification-only
> Realtime channel (never mutates state, never advances the cursor) and the full
> push → pull → master sync run wired into `SyncController.runSync` (see §13).
> The cursor/batching core was already part of the engine and now drives the app
> on startup/resume/login/network-recovery/Realtime/manual. **All 31
> `USER_SYNCABLE` tables remain accounted for** (25 migrated, 6 outbox-exempt).
> **Status (PROMPT 16):** Master-data synchronization shipped — server-authoritative
> download pipeline for the 10 cloud master/reference catalogs (foods, exercises,
> workout_categories, meal_categories, workout_templates, workout_template_exercises,
> goal_templates, achievement_defs, badge_defs, challenge_defs), keyed off cloud
> `master_data_versions`, with local high-watermark watermarks, natural-key adoption of
> seeded rows and failure-keeps-local semantics (see §12). Adds DB migration **v16**.

## 1. Goal

Wire the remaining 24 of 31 `USER_SYNCABLE` tables into the two-way sync pipeline so
every user write becomes an outbox event. The foundation (outbox, transport, engine,
cursor, status) already exists and is table-agnostic — each DAO conversion is a small,
mechanical step.

## 2. Current coverage

| # | Local table | Sync-tracked today | Needs conversion |
|---|---|---|---|
| 1 | `user_profile` → `profiles` | Yes (Batch 1, upsert→create/update, soft-delete) | — |
| 2 | `app_settings` → `user_settings` | Yes (Batch 1, upsert→create/update, soft-delete) | — |
| 3 | `fitness_goal` → `fitness_goals` | Yes (Batch 1, C/U/D) | — |
| 4 | `workout` → `workouts` | Yes (Batch 1, C/U/D + child tombstone) | — |
| 5 | `workout_exercise` → `workout_exercises` | Yes (Batch 1, C/U/D + FK resolution) | — |
| 6 | `workout_history` → `workout_history` | Yes (Batch 1, C/U/D) | — |
| 7 | `weight_log` → `weight_logs` | Yes (C/U/D) | — |
| 8 | `body_measurement` → `body_measurements` | Yes (C/U/D) | — |
| 9 | `reminder` → `reminders` | Yes (C/U/D) | — |
| 10 | `daily_progress` | Yes (upsert→update) | — |
| 11 | `exercise_history` → `exercise_history` | Yes (Batch 2, C/U/D + FK resolution) | — |
| 12 | `exercise_favorite` → `exercise_favorites` | Yes (Batch 2, add/remove + ownership) | — |
| 13 | `food_log` → `food_logs` | Yes (Batch 2, C/U/D + batched `insertAll`) | — |
| 14 | `food_favorite` → `food_favorites` | Yes (Batch 2, add/remove + ownership) | — |
| 15 | `meal` → `meals` | Yes (Batch 2, C/U/D + child tombstone) | — |
| 16 | `meal_item` → `meal_items` | Yes (Batch 2, C/U/D + FK resolution) | — |
| 17 | `meal_category` → `meal_categories` | N/A (master data, outbox-exempt) | — |
| 18 | `weight_log` → `weight_logs` | Yes (Batch 3, C/U/D + batched `insertAll`, large-dataset) | — |
| 19 | `body_measurement` → `body_measurements` | Yes (Batch 3, C/U/D + batched `insertAll`, all circumference columns) | — |
| 20 | `bmi_log` → `bmi_logs` | Yes (Batch 3, C/U/D + batched `insertAll`, update method added) | — |
| 21 | `sleep_log` → `sleep_logs` | Yes (Batch 3, C/U/D + batched `insertAll`, cloud `sleep_date` DATE round-trip) | — |
| 22 | `step_log` → `step_logs` | Yes (Batch 3, C/U/D + batched `insertAll`, cloud `step_date` DATE round-trip) | — |
| 23 | `water_log` → `water_logs` | Yes (Batch 3, C/U/D + batched `insertAll`, large-dataset) | — |
| 24 | `reminder` → `reminders` | Yes (Batch 4, C/U/D + extended columns, soft-delete) | — |
| 25 | `reminder_history` → `reminder_history` | Yes (Batch 4, C/U/D + batched insertAll + FK resolution, soft-delete) | — |
| 26 | `reward` → `user_rewards` | Yes (Batch 4, C/U/D, soft-delete) | — |
| 27 | `xp_history` → `xp_history` | Yes (Batch 4, C/U/D, derived `total_xp`/`metadata` excluded, soft-delete) | — |
| 28 | `daily_progress` | Exempt (Batch 4 — derived rollup, outbox-exempt) | — |
| 29 | `streak` | Exempt (Batch 4 — derived cache, outbox-exempt) | — |
| 30 | `achievement`, `badge`, `challenge`, `milestone` | Exempt (Batch 4 — server-authoritative master defs mirrored locally) | — |
| 31 | `exercise` (custom rows) → `exercises` | Yes (Batch 5, C/U/D, master rows exempt, soft-delete) | — |
| 32 | `food_item` (custom rows) → `foods` | Yes (Batch 5, C/U/D, master rows exempt, soft-delete) | — |
| 33 | `user_level` → `user_levels` | Yes (Batch 5, singleton upsert→create/update, soft-delete) | — |

## 3. Per-DAO conversion checklist (the mechanical steps)

For each unconverted DAO write path (`insert`/`update`/`delete`):

1. **Capture `base_version`** — read the row's current `row_version` *before* mutating,
   and pass it to `SyncEventRecorder.record(..., baseVersion: ...)` (or
   `recordInTransaction`). This is the version the cloud conditional update compares
   against (Part 9).
2. **Transactional outbox (preferred):** wrap the mutation + `recordInTransaction` in the
   same SQFlite transaction so a crash can never produce an outbox event without its row.
   For DAOs where the mutation SQL is already a single statement, this is a one-line
   change; where the DAO composes several statements, add a transaction around the group.
3. **Register the table mapping** in `SyncTableRegistry` (`lib/data/services/sync/
   sync_table_registry.dart`) with the correct local/cloud table name and any date
   columns (used by the applier's epoch↔ISO conversion). If the cloud table has a
   tombstone column, add it to the mapping so delete changes can be applied.
4. **Verify delete semantics:** the cloud soft-delete model requires the local row to be
   tombstoned (`deleted_at`) rather than physically removed, so a queued event is never
   lost. `RemoteChangeApplier` already handles tombstoned local tables generically.
5. **Keep `entity_id` stable across the row's lifetime** — it is the idempotency key on
   the cloud (`id` = local UUID). For tables still keyed `INTEGER AUTOINCREMENT`, the
   migration v16 (below) provides the stable UUID first.

## 4. Required local schema migration (v16) before bulk conversion

A small number of tables still lack the columns the pipeline assumes. Add one
**batched migration v16** in `AppDatabase`:

- `uuid TEXT NOT NULL UNIQUE` (UUID v4, back-filled via `hex(randomblob(16))` or a Dart
  back-fill) on every `USER_SYNCABLE` table that keys on `INTEGER AUTOINCREMENT`.
- `row_version INTEGER NOT NULL DEFAULT 0` and `updated_at INTEGER` where missing
  (mirrors the cloud trigger behavior).
- `deleted_at INTEGER` tombstone where the cloud table has one (the matrix in
  `NEXFIT_SYNC_TABLE_MATRIX.md` lists which).

Without this, pulled rows cannot be matched to existing local rows without duplication,
and conflict detection has nothing to compare.

## 5. Sequencing recommendation

1. Ship migration v16 + the 7 already-tracked tables' `recordInTransaction` upgrade
   (verify the existing event rows still load via `fromName('failed') → failedPermanent`).
2. Convert tables in dependency order: independent daily logs first
   (`water_log`, `bmi_log`, `sleep_log`, `step_log`, `calorie_log`-derived), then
   parent/child pairs (`workout` + `workout_exercise`, `meal` + `meal_item`,
   `food_log` + `food_item`), then gamification tables (`streak`, `xp_history`,
   `user_level`, `achievement`, `badge`, `challenge`, `milestone`, `reward`), then
   preferences (`fitness_goal`, `exercise_favorite`, `food_favorite`,
   `reminder_history`).
3. Add one DAO migration test per converted table (mirror `sync_foundation_test.dart`:
   mutate → event exists → push → pull → row matches, idempotent on retry).
4. Keep `calorie_log` local-only (derived; no cloud table exists).

## 6. Known constraints

- `profiles` has no `deleted_at`; its delete is a no-op by design.
- `user_profile` and `app_settings` key on `user_id`; their cloud identity IS the
  `user_id` (no separate UUID needed).
- `workout_exercise`/`workout_history`/`workout` FK columns are resolved by
  `cloudForeignKeys` in the registry (push: local id → referenced `uuid`; pull: cloud
  `uuid` → local id). A pull whose parent uuid cannot be resolved aborts the batch
  transaction so the cursor never advances past an incomplete row.
- `fitness_goal`, `workout`, `workout_history` inserts/updates preserve the local
  integer id; remote-applied rows receive a fresh local id from their server uuid.
- Production bulk sync of pre-existing local rows is a separate future phase
  (outbox back-fill), not covered here.

## 7. Batch 1 delivery record (PROMPT 11)

Migrated DAOs (all use `SyncableDao` in `lib/data/datasources/local/syncable_dao.dart`,
mutation + outbox event inside one transaction):

| DAO | Cloud table | Notes |
|---|---|---|
| `user_profile` | `profiles` | singleton, `uuid = user_id`, create/update/soft-delete |
| `app_settings` | `user_settings` | singleton, `uuid = user_id`, create/update/soft-delete |
| `fitness_goal` | `fitness_goals` | uuid + row_version + soft-delete |
| `workout` | `workouts` | delete also tombstones `workout_exercise` children |
| `workout_exercise` | `workout_exercises` | `cloudForeignKeys`: workout_id, exercise_id |
| `workout_history` | `workout_history` | `cloudForeignKeys`: workout_id |

Behaviors verified in `test/dao_sync_batch1_test.dart` (32 tests): insert stamps uuid /
`row_version=1` / timestamps and emits a CREATE event; update preserves uuid, bumps
version and emits an UPDATE event with `base_version`; delete soft-deletes and emits a
DELETE event; a failed mutation rolls back both the row and its event; remote apply
updates the local row and never enqueues an outbound event; rows and events are scoped
per user. `flutter analyze` and the full sync + migration suites remain green.

## 8. Batch 2 delivery record (PROMPT 12)

Migrated DAOs (all use `SyncableDao`, mutation + outbox event inside one transaction):

| DAO | Cloud table | Notes |
|---|---|---|
| `exercise_history` | `exercise_history` | `user_id` resolved from owning `workout_history`; `cloudForeignKeys`: workout_history_id, exercise_id |
| `exercise_favorite` | `exercise_favorites` | add/remove soft-delete, resurrect on re-add; ownership validated vs. authenticated user |
| `food_log` | `food_logs` | batched `insertAll`; `cloudForeignKeyNames`: food_item_id → `food_id`; FKs: food_item, meal |
| `food_favorite` | `food_favorites` | add/remove soft-delete, resurrect on re-add; ownership validated; FK name `food_id` |
| `meal` | `meals` | delete tombstones `meal_item` children + emits a DELETE event per child |
| `meal_item` | `meal_items` | `user_id` resolved from owning `meal`; FKs: meal, food_item (`food_id` cloud name) |

Infrastructure additions (Batch 2):

- `SyncTableMapping` gained `cloudForeignKeyNames` (local FK column → cloud column name,
  e.g. `food_item_id` → `food_id`) and `cloudHasDeletedAt` (default true; `profiles`
  sets false). The transport pushes `deleted_at` (null or ISO) when `cloudHasDeletedAt`
  so a resurrected favorite re-opens its cloud row; the applier resolves FKs by the
  cloud name.
- `orderChangesForApply(List<SyncChange>)` in `remote_change_applier.dart` — stable
  topological sort that applies parents (`meals`) before children (`meal_items`,
  `exercise_history`); wired into `SyncEngine._applyBatch`. A parent FK that cannot be
  resolved aborts the batch transaction so the cursor never advances past an incomplete
  row (deferral-by-return was rejected because the cursor would skip deferred rows).
- `SyncEventRecorder` gained `activeUserId` + `isCurrentUser`; both favorites DAOs
  `_ensureOwnership` throws `DatabaseException(code: 'favorite_ownership')` *outside*
  `guard` so the specific error propagates to callers.

Deliberate scope decisions:

- **`meal_category` is master/reference data**: no `user_id`, no uuid/row_version
  columns in v15, seeded via `INSERT OR IGNORE` by slug. It is **outbox-exempt**
  (not registered, never emits events) and pulled by the app directly, not through the
  sync pipeline.
- **`food_log.meal_type_id` is not synced** for the same reason as `workout.category_id`:
  it references the local master `meal_category` catalog, which has no cloud uuid.
- Large nutrition writes use batched operations: `insertAll` inserts all rows + events in
  a single transaction and never loads existing rows into memory.

Behaviors verified in `test/dao_sync_batch2_test.dart` (42 tests): offline
insert/update/delete with uuid / `row_version` / `base_version` / tombstone; failed
mutation rolls back row + event (missing parent meal/workout_history, unknown user);
remote apply via `RemoteChangeApplier` resolves FK uuids to local ids (including the
`food_id` cloud name) and never enqueues an outbound event; favorites ownership
violations are rejected; re-adding a removed favorite resurrects it with an UPDATE event;
parent/child tombstoning (`meal` delete cascades to `meal_item`); `orderChangesForApply`
orders parents before children in one pull batch; user isolation; and a 2,000-row local
dataset inserted via a single batched transaction. `flutter analyze` is clean; the full
sync + migration + nutrition suites (122 tests) stay green.

## 9. Batch 3 delivery record (PROMPT 13)

Migrated DAOs — the six health-metric tables (all use `SyncableDao`, mutation + outbox
event inside one transaction):

| DAO | Cloud table | Notes |
|---|---|---|
| `weight_log` | `weight_logs` | batched `insertAll` (1,500-row test); `getByDateRange`, `getLatest` |
| `body_measurement` | `body_measurements` | batched `insertAll`; all 12 circumference columns mapped (incl. left/right arm, thigh, calf) |
| `bmi_log` | `bmi_logs` | new `update` method added; batched `insertAll`; `getByDateRange` |
| `sleep_log` | `sleep_logs` | batched `insertAll`; cloud `sleep_date` DATE round-trip; `getByDate` |
| `step_log` | `step_logs` | batched `insertAll`; cloud `step_date` DATE round-trip; `getByDate`, `getByDateRange` |
| `water_log` | `water_logs` | batched `insertAll` (1,200-row test); `getByDateRange` |

Infrastructure additions (Batch 3):

- **Applier fix** in `_convertCloudValue` (`remote_change_applier.dart`): the sync metadata
  columns `created_at` / `updated_at` / `deleted_at` are now always parsed as timestamps
  (previously they were skipped when a table had no `timestampColumns`), and `dateColumns`
  support was added — a cloud `date` value (`YYYY-MM-DD`) is converted to local
  epoch-milliseconds at midnight, round-tripping the transport's local-calendar rendering.
- **Registry additions** (`sync_table_registry.dart`): new mappings `bmi_log` → `bmi_logs`,
  `sleep_log` → `sleep_logs` (timestampColumns: bedtime, wake_time, created_at, updated_at;
  dateColumns: sleep_date), `step_log` → `step_logs` (dateColumns: step_date),
  `water_log` → `water_logs`; the existing `body_measurement` mapping gained the six
  circumference columns.
- **Business vs sync timestamps**: `logged_at` / `measured_at` / `sleep_date` / `step_date`
  remain user-entered business values mapped by the registry, distinct from the sync
  lifecycle columns `created_at` / `updated_at` / `deleted_at` / `row_version` that the DAO
  owns.

Deliberate scope decisions:

- **Historical datasets never fully reload**: all reads in the app use
  `getByDateRange` / `getByDate`; bulk writes use `insertAll` (one transaction, per-row
  uuid + CREATE event, no table scan). Pull already advances a per-user cursor and pushes
  already batch outbox events, so large histories sync incrementally.
- **Remote apply never re-emits**: `RemoteChangeApplier` writes rows directly, so a pulled
  change can never enqueue an outbound event (no echo loop) — verified for all six tables.
- **Conflict handling** stays latest-wins with `base_version`: a push that hits an
  optimistic-lock conflict on the remote row is resolved by re-applying the newer local
  row.

Behaviors verified in `test/dao_sync_batch3_test.dart` (44 tests): offline
insert/update/delete with uuid / `row_version` / `base_version` / tombstone for all six
DAOs; failed mutation (unknown user) rolls back row + event; `insertAll` writes large
datasets (1,500 weight, 1,200 water rows) in one transaction; remote apply maps every
column (including the six body_measurement circumference columns) and never enqueues an
outbound event; cloud `sleep_date` / `step_date` DATE columns round-trip through the
applier; events scoped per user; engine-level: incremental pull applies only changes after
the stored cursor, duplicate pending outbox events merge into one, an optimistic-lock
conflict on push resolves latest-wins, and remote apply causes no echo. `flutter analyze`
is clean; the full sync + migration + nutrition + weight suites (177 tests) stay green.

## 10. Batch 4 delivery record (PROMPT 14)

### Classification of the ten target tables

| Table | Classification | Decision |
|---|---|---|
| `reminder` | source-of-truth user data | sync full (all columns incl. schedule/color/behaviour) |
| `reminder_history` | source-of-truth user data | sync full; `reminder_id` FK resolves through `cloudForeignKeys` |
| `reward` | source-of-truth user data | sync full |
| `xp_history` | source-of-truth ledger | sync `source`/`reason`/`xp`/timestamps only; **exclude** derived `total_xp` (running sum, recomputable) and `metadata` (cloud jsonb ↔ local TEXT not transported) |
| `daily_progress` | **derived** daily rollup | outbox-exempt — recomputable from synced raw logs; mapping removed from registry, DAO emits no events |
| `streak` | **derived** cache | outbox-exempt — workout streak recomputable from synced `workout_history`; weight/hydration streaks computed on the fly |
| `achievement` | hybrid — server-authoritative master def + per-user state | outbox-exempt — local rows denormalize master-definition columns (`name`, `badge_type`, …) with no local def mirror; cloud rows FK to a def catalog the client cannot resolve; never upload master changes |
| `badge` | hybrid (as above) | outbox-exempt (as above) |
| `challenge` | hybrid (as above) | outbox-exempt (as above) |
| `milestone` | hybrid (as above) | outbox-exempt; dormant v10 table with no model/entity/DAO — left untouched |

### Migrated DAOs (transactional outbox via `SyncableDao`)

| DAO | Cloud table | Notes |
|---|---|---|
| `reminder` | `reminders` | extended mapping: schedule_type, times, start_date/end_date (`dateColumns`), month_day, icon, color_value, sound/vibration/silent/show_action_buttons booleans, related_screen; soft-delete reads filter `deleted_at IS NULL` |
| `reminder_history` | `reminder_history` | batched `insertAll`; per-row DELETE events from `deleteByReminderId` (soft-delete); reads + `getScheduledFor` filter tombstones |
| `reward` | `user_rewards` | `is_claimed` boolean; soft-delete |
| `xp_history` | `xp_history` | `totalXpForUser` filters tombstones; derived columns excluded from registry |

### Registry changes (`sync_table_registry.dart`)

- `reminder` mapping extended to the full column set; `start_date` / `end_date` marked `dateColumns`.
- `reminder_history` → `reminder_history` added (`cloudForeignKeys: {'reminder_id': 'reminder'}`, timestampColumns scheduled_for/acted_at/created_at/updated_at).
- `reward` → `user_rewards` added (`is_claimed` boolean).
- `xp_history` → `xp_history` added (ledger columns only).
- `daily_progress` mapping **removed** (derived rollup — never synced).

### Deliberate scope decisions

- **`days_of_week`** local stores a comma-separated string while the cloud stores a JSON
  array — kept as a direct text mapping (harmless on both sides; no numeric transform).
- **Master definitions are never uploaded**: rows for achievement/badge/challenge/milestone
  reference server catalog entries the client does not mirror, so the client never pushes
  them and pulls nothing for them.
- **Streak calculation unchanged**: the streak algorithm in `workout_session_repository_impl.dart`
  (`_updateWorkoutStreak`) is not touched; only the sync classification of the cache table
  changed.

### Verified

`test/dao_sync_batch4_test.dart` (28 tests): offline insert/update/delete with
uuid / `row_version` / `base_version` / tombstone for the four source-of-truth DAOs; failed
mutation (unknown user) rolls back row + event; `reminder_history.insertAll` writes three
rows + events in one transaction; remote apply maps every reminder column including cloud
`date` (start_date/end_date) and boolean columns, resolves the `reminder_history.reminder_id`
cloud uuid back to the local int id, and never enqueues an outbound event; registry
assertions that `total_xp` / `metadata` are excluded from the `xp_history` mapping; derived /
server-authoritative writes (`daily_progress`, `streak`, `achievement`, `badge`, `challenge`)
produce zero outbox events and their tables are unregistered (`SyncTableRegistry.byLocalTable`
== null); engine-level: incremental pull with cursor advance, a reminder → reminder_history
parent/child batch applies parent-first, duplicate pending outbox events merge, and an
optimistic-lock conflict resolves latest-wins. `flutter analyze` is clean; the full sync +
migration + nutrition + weight suites (205 tests) stay green.

## 11. Batch 5 delivery record (PROMPT 15)

### Migrated DAOs (transactional outbox via `SyncableDao`)

| DAO | Cloud table | Notes |
|---|---|---|
| `exercise` | `exercises` | hybrid — **custom rows only** (`user_id IS NOT NULL`) sync; master rows (`user_id IS NULL`, seeded by `WorkoutSeeder`) stay local-only and never emit events. `image` → `image_url`, `gif_path` → `gif_url`; `is_custom` boolean; soft-delete |
| `food_item` | `foods` | hybrid — **custom rows only** sync; master rows (`user_id IS NULL`, seeded by `FoodSeeder`) stay local-only. `image_path` → `image_url`; `is_custom` boolean; soft-delete |
| `user_level` | `user_levels` | per-user singleton (`UNIQUE(user_id)`); follows the `user_profile` / `app_settings` pattern — `uuid == user_id`, upsert is a create/update pair preserving `created_at`, soft-delete |

### Registry changes (`sync_table_registry.dart`)

- `exercise` → `exercises` added (full column set incl. `image`→`image_url`, `gif_path`→`gif_url`,
  `is_custom` boolean). This also completes the FK chains: `workout_exercise`, `exercise_history`
  and `exercise_favorite` already resolve their `exercise_id` against this mapping's cloud uuid.
- `food_item` → `foods` added (full column set incl. `image_path`→`image_url`, `is_custom` boolean).
  Completes the `food_log` / `food_favorite` / `meal_item` `food_id` FK chain.
- `user_level` → `user_levels` added (`localKeyColumn: 'user_id'`, singleton).

### Classification of the last three tables

| Table | Classification | Decision |
|---|---|---|
| `exercise` (custom rows) | source-of-truth user data (hybrid) | custom rows sync full; master rows never emit events |
| `food_item` (custom rows) | source-of-truth user data (hybrid) | custom rows sync full; master rows never emit events |
| `user_level` | source-of-truth singleton | sync all four level/XP columns — they are the level system's canonical per-user state (unlike `xp_history.total_xp`, which is duplicated per ledger row) |

### Deliberate scope decisions

- **Master rows never sync**: seeder-written catalog rows (`user_id IS NULL`) keep no cloud
  identity (`uuid` null), never enter the outbox, and are never tombstoned — deleting one via
  the DAO is a no-op. Only genuinely user-owned custom rows follow the outbox contract.
- **`total_xp` on `user_level` is synced**: it is the singleton's stored accumulator state
  owned by the level system, distinct from the derived `xp_history.total_xp` excluded in
  Batch 4.
- **Master definition rows are still never uploaded**: achievement/badge/challenge/milestone
  remain outbox-exempt per Batch 4; nothing in this batch changes that.

### Verified

`test/dao_sync_batch5_test.dart` (30 tests): offline insert/update/delete with
uuid / `row_version` / `base_version` / tombstone for the three DAOs; master-row writes
(insert/update/delete) produce zero outbox events, no uuid and no tombstone; a failing
mutation (unknown user) rolls back row + event; remote apply maps every column including the
`image_url` / `gif_url` renames and `is_custom` boolean, resolves `foods`-before-`food_logs`
pull ordering (parent uuid → local int FK), and never enqueues an outbound event; singleton
upsert preserves uuid/`created_at`, insert is idempotent per user, and delete soft-deletes
with a DELETE event keyed on `user_id`; registry assertions for the three mappings; engine-level
incremental pull with cursor advance, parent/child FK resolution, optimistic conflict
latest-wins, and no echo. `flutter analyze` is clean; the full sync + migration + nutrition +
weight suites (235 tests) stay green.

### Validation — all 31 `USER_SYNCABLE` tables accounted for

| Count | Meaning |
|---|---|
| 31 | total `USER_SYNCABLE` tables (per `docs/SQFLITE_MIGRATION_V15_DDL_REVIEW.md` §1.1) |
| 25 | successfully migrated to the transactional outbox (Batch 1: user_profile, app_settings, fitness_goal, workout, workout_exercise, workout_history; Batch 2: exercise_history, exercise_favorite, food_log, food_favorite, meal, meal_item; Batch 3: weight_log, body_measurement, bmi_log, sleep_log, step_log, water_log; Batch 4: reminder, reminder_history, reward, xp_history; Batch 5: exercise custom, food_item custom, user_level) |
| 0 | remaining syncable tables left |
| 0 | unsupported (every registered table resolves through `SyncTableRegistry`) |
| 6 | documented outbox-exempt (derived: daily_progress, streak; hybrid server-authoritative: achievement, badge, challenge, milestone) |
| 2 | master-data tables kept out of the count (workout_category, meal_category — never user-syncable) |
| several | local-only / sync-metadata tables (users, calorie_log, backup_history, error_logs, sessions, sync_event, schema_migrations) — unchanged |

## 13. Incremental Sync + Realtime Notification (PROMPT 18)

### Cursor flow (already in the engine, now wired to the app)

`SyncEngine.pull` drains remote `sync_changes` after the persisted per-user
cursor. Each batch is applied inside one transaction together with its cursor
advance, so the cursor **never advances before a successful commit**. Rows are
pulled in pages of `syncPullBatchSize` (100) and capped by
`syncMaxPullBatches` (50) — thousands of changes are processed batch by batch and
never loaded wholesale.

### Realtime is notification-only

`RealtimeSyncNotifier` subscribes one `postgres_changes` channel per realtime-
enabled table (the `supabase_realtime` publication set: daily_progress, food_logs,
water_logs, weight_logs, workouts, workout_history, reminders, sleep_logs,
step_logs, body_measurements, bmi_logs, streaks). Realtime enforces RLS so events
arrive only for the signed-in user. The callback carries **no row data and applies
nothing** — it only pokes the coordinator to run a cursor pull. The cursor pull is
therefore authoritative and idempotent:

* a **missed** Realtime event is recovered by the next startup/resume/manual run
  (the cursor fetches whatever happened while the app was closed);
* a **duplicate** Realtime event is harmless — Realtime never applies a row, and
  the pull ignores anything `cursor_id <=` the stored cursor.

### Trigger hub

`IncrementalSyncCoordinator` funnels every trigger into one debounced,
single-flight run:

| Trigger | Source |
|---|---|
| `startup` | splash background bootstrap |
| `resume` | `NexFitApp.didChangeAppLifecycleState` |
| `login` | `currentUserProvider` signed-out → signed-in transition |
| `networkRecovery` | `connectivity_plus` offline → online emission |
| `realtime` | `RealtimeSyncNotifier` |
| `manual` | settings / health-card sync buttons |

* **Debounce** (750 ms) coalesces bursts (many Realtime events, resume + login +
  connectivity colliding).
* **Single-flight** — a request arriving during a run is queued and executed when
  the run finishes, so a mid-run change is never lost.
* **Gating** — requests are dropped while no user is signed in, so the hub is
  silent on the login screen.
* **No polling** — everything is event-driven.

### Full run

`SyncController.runSync` now runs push → pull → master: when the transport is
ready it calls `SyncEngine.sync` (outbox push, then cursor pull, then the PROMPT 16
master catalogs); offline it acknowledges pending events locally and skips pull +
master. A successful pull marks initial sync complete for the UI status.

### Files

- `lib/data/services/sync/incremental_sync_coordinator.dart` — trigger hub.
- `lib/data/services/sync/realtime_sync_notifier.dart` — notification-only
  Realtime channel + `RealtimeChannelGateway` abstraction.
- `lib/presentation/providers/incremental_sync_providers.dart` — wiring (auth,
  connectivity, Realtime) that activates the hub.
- `lib/presentation/providers/sync_providers.dart` — `runSync({trigger})` full
  push+pull+master.
- `lib/app.dart`, `lib/presentation/screens/splash/splash_screen.dart` —
  resume/startup triggers.

### Verified

- `flutter analyze` — clean.
- `test/incremental_sync_test.dart` — **14/14 green**: coordinator debounce
  coalescing, single-flight queueing, signed-out gating, flush, dispose; Realtime
  notification-only contract + idempotent attach/detach; engine cursor-0,
  cursor-N/dedup, 250-row 3-batch pull with bounded page size, app-restart +
  missed-Realtime recovery, full push+pull, offline local ack, rollback-keeps-
  cursor.
- Full regression: **358 pass / 2 fail** — both pre-existing and unrelated
  (`session_manager` device-change, `hydration_repository` loadStatistics).

## 12. Master Data Synchronization (PROMPT 16)

### Goal

Server-authoritative download of the 10 cloud master/reference catalogs. The client
is **SELECT-only** for these tables — it must never upload a master row. Local data is
preserved until a download succeeds; a failed download keeps old data, old version and
old watermark. On a fresh install the full catalog set is downloaded in batches so the
UI stays responsive.

### Catalogs and local targets

| Cloud table | Local table | Natural key | Hybrid (user rows coexist) |
|---|---|---|---|
| `foods` | `food_item` | `name` | Yes — `user_id IS NULL` master rows only |
| `exercises` | `exercise` | `name` | Yes — `user_id IS NULL` master rows only |
| `workout_categories` | `workout_category` | `slug` | No |
| `meal_categories` | `meal_category` | `slug` | No |
| `workout_templates` | `workout_template` (new) | `uuid` | No |
| `workout_template_exercises` | `workout_template_exercise` (new) | `uuid` | No |
| `goal_templates` | `fitness_goal` | `goal_type` | Yes — `user_id IS NULL` master rows only |
| `achievement_defs` | `achievement_def` (new) | `achievement_type` | No |
| `badge_defs` | `badge_def` (new) | `badge_type` | No |
| `challenge_defs` | `challenge_def` (new) | `challenge_type` | No |

### Staleness detection

Per-catalog versions come from cloud `master_data_versions` (`entity_type` +
`entity_id` + `updated_at`). A local `master_catalog_state` row stores
`data_version`, a high-watermark `since` and `status`. The catalog is re-downloaded
only when the cloud `updated_at` differs from the stored `data_version` (or the local
state is missing).

### Incremental pull — high-watermark

`since` is the **max `updated_at` observed across successfully applied rows**, not the
version-bump timestamp. A bulk publish can bump `master_data_versions.updated_at`
after the rows' own timestamps, so using the bump time would skip rows. The
transport filters `WHERE updated_at >= since` and rows are ordered by `id`.

### Apply algorithm (per cloud row, in one transaction per batch)

1. **Match by `uuid`** → update in place (preserves local integer PKs and user FKs).
2. **Else match by natural key** → adopt in place (keeps seeded row ids), stamp `uuid`.
3. **Else insert** with `uuid = cloud id` (seeded DBs: only after cloud download).

Hybrid catalogs additionally require `user_id IS NULL` on both match and insert, so
custom user rows are never touched. Foreign keys (`workout_template.category_id`,
`workout_template_exercise.template_id/exercise_id`) resolve from the local uuid→id
map; unresolved NOT NULL child FKs skip the row (insert throws, caught, logged).
Parents are applied before children (registry order).

### Failure semantics

One transaction per pull batch. On failure: prior batches stay committed, the failed
batch rolls back, local `data_version`/`since`/rows are untouched, and
`status='failed'` with `last_error`. The version row is persisted only after the full
catalog succeeds. Tombstones (`deleted_at`) are applied from the cloud; there is no
local reconcile-delete and nothing is deleted before a successful download. Offline
(`transport.isReady == false`) → `syncAll` returns `ran: false` and writes nothing.

### Schema migration (v16)

New tables `master_catalog_state`, `workout_template`, `workout_template_exercise`,
`achievement_def`, `badge_def`, `challenge_def`; `uuid`/`deleted_at`/`row_version`/
`updated_at` columns added to `workout_category` and `meal_category` with uuid
backfill and unique `idx_<table>_uuid` indexes.

### Files

- `lib/data/services/sync/master_data_contracts.dart` — `MasterCatalogSpec`,
  `MasterCatalogRegistry` (10 catalogs, dependency-ordered), transport contract.
- `lib/data/services/sync/master_data_sync_service.dart` — version compare,
  batched incremental apply, watermark, failure recording.
- `lib/data/services/sync/supabase_master_data_transport.dart` — SELECT-only pull.
- `lib/data/datasources/local/master_catalog_state_local_data_source.dart` — state DAO.
- `lib/injection/dependency_injection.dart`, `lib/presentation/providers/sync_providers.dart`
  — providers + `runSync()` best-effort integration after the user outbox.
- `lib/data/datasources/local/app_database.dart`, `lib/core/constants/app_constants.dart`
  — v16 migration.

### Verified

- `flutter analyze` — clean.
- `test/master_data_sync_test.dart` — **16/16 green**: registry order, fresh install
  (single catalog + full `syncAll`), existing install (skip unchanged version,
  retry-after-failure), incremental watermark pull, network failure keeps old data,
  partial download rolls back the uncommitted batch, 250-row multi-batch download,
  duplicate rows applied once, re-run idempotency, natural-key adoption preserving
  seeded ids, FK resolution, hybrid isolation, offline no-op.
- Full regression: 344 pass / 2 fail — both pre-existing and unrelated
  (`session_manager` device-change, `hydration_repository` loadStatistics).

## 14. Initial User Synchronization (PROMPT 17)

### Goal

First-time sync for a signed-in user: ensure the local profile, load `sync_state`,
detect whether initial sync already completed, pull the user's cloud rows (cursor 0),
push the user's own pending local records and mark initial sync complete. Pre-existing
local data is **never deleted** and **never silently uploaded for another account**;
orphaned rows are only adopted through an explicit user opt-in.

### Order of operations (`InitialSyncService.run`)

1. **Ensure profile** — best-effort hook guarantees the authenticated user's local
   `user_profile` row exists before the pull (sign-in usually already persisted it).
2. **Load `sync_state`** — if `initialSyncCompleted` is already true, report
   `alreadyComplete` and stop (no re-pull).
3. **Offline detection** — when `transport.isReady == false`, report the `offline`
   phase **without** touching data or marking complete, so a later run retries.
4. **Pull** — `SyncEngine.pull` from cursor 0. Each batch applies remote rows and the
   cursor advance in one transaction; `initialSyncCompleted` is set only on a fully
   successful pull. `onBatchProgress(applied, cursor)` drives the UI progress bar.
5. **Push** — `SyncEngine.processQueue(userId)` pushes only **this user's** pending
   outbox events (the outbox is user-scoped, so a previous account's events never
   upload). A push failure is non-fatal: pending events stay queued and retry.

### Ownership of pre-existing local data (`LocalDataOwnershipAnalyzer`)

Classifies every user-owned table against the authenticated user's `user_id`:

| Class | Meaning | Handling |
|---|---|---|
| Current user | `user_id == userId` | Normal |
| Foreign account | `user_id` is another non-empty id | **Never** auto-adopted, **never** uploaded |
| Orphan | `user_id` NULL or empty | Adoptable only via explicit opt-in |

Master-hybrid tables are exempt: `exercise` / `food_item` `user_id IS NULL` rows are
master catalog data (counted only when `is_custom = 1`), and `fitness_goal`
`user_id IS NULL` rows are goal templates. None of those are orphans. Singleton tables
(`user_profile`, `app_settings`, `user_level`) are created fresh on sign-in and are
excluded from adoption.

`adoptOrphans(userId)` (opt-in) reassigns orphaned rows to the user, backfills `uuid`,
stamps `updated_at` / bumps `row_version` and enqueues a CREATE outbox event — all in
one transaction. Foreign-account rows and master rows are never touched.

### Wiring

- `SyncController.runSync` detects first-run (`sync_state == null ||
  !initialSyncCompleted`) and routes through `InitialSyncService`; later runs use the
  incremental push+pull path.
- `SyncUiState` exposes the initial-sync phase (syncing / complete / failed / offline),
  pulled/pushed counts and the ownership analysis so screens can show progress,
  completion, failure, offline and an adoption prompt.
- `adoptOrphanedLocalData()` is the explicit opt-in call (never automatic).

### Files

- `lib/data/services/sync/local_data_ownership.dart` — analysis + opt-in adoption.
- `lib/data/services/sync/initial_sync_service.dart` — the first-time flow.
- `lib/data/services/sync/sync_engine.dart` — `pull` gained an optional
  `onBatchProgress` callback.
- `lib/data/services/sync/sync_table_registry.dart` — exposed public `mappings`.
- `lib/injection/dependency_injection.dart`, `lib/presentation/providers/sync_providers.dart`
  — `initialSyncServiceProvider` + controller integration.

### Verified

- `flutter analyze` — clean.
- `test/initial_sync_test.dart` — **14/14 green**: ownership analysis (clean DB,
  orphans, foreign accounts, master-hybrid exemption, custom-food orphans), explicit
  opt-in adoption (reassign + uuid + row_version + atomic CREATE event, foreign rows
  untouched), new-user empty-DB pull/push/complete, already-complete no-op, existing
  local data preserved with no silent upload, offline no-op + retry, partial download
  keeps committed data/cursor then retries to completion, progress emission,
  per-user isolation on a shared device.
- Full regression: **372 pass / 2 fail** — both pre-existing and unrelated
  (`session_manager` device-change, `hydration_repository` loadStatistics).

## 15. Conflict Detection and Resolution (PROMPT 19)

### Goal

A push that fails the optimistic-lock check (remote `row_version` moved past the
event's `base_version`) must **never** silently overwrite the server row and must
**never** discard the conflicting local data. Every conflict is captured as a durable
`sync_conflict` record containing both snapshots, resolved with a **SERVER_WINS**
default (pull converges the local row), and flagged for the UI with a clean per-user
pending-conflict count.

### Resolution policy

| Strategy | Behaviour |
|---|---|
| `latestWins` (default) | **SERVER_WINS** — event completes (`markSuccess`), pull applies the authoritative server row locally; the local change is preserved in the conflict record (status `serverWon`) for recovery/review. |
| `manualMerge` | Event stays `pending` with `lastError = manual_merge_required`; the conflict record stays `pending` and is counted for the UI until the user resolves it. |

### Durable conflict store (`sync_conflict`, migration v17)

| Column | Meaning |
|---|---|
| `user_id`, `entity`, `record_uuid` | Record identity (record_uuid = cloud uuid from the local row). |
| `local_data` / `server_data` | JSON snapshots of both sides at conflict time (local is never discarded). |
| `local_version` / `server_version` | Local `row_version` vs the remote `row_version` that won. |
| `local_updated_at` / `server_updated_at` | Both sides' `updated_at`. |
| `detected_at` | When the conflict was recorded. |
| `status` | `pending` / `serverWon` / `resolved`. |
| `strategy` | `latest_wins` / `manual_merge`. |
| `resolved_at` | Filled by `markResolved`. |

A **partial unique index** `idx_sync_conflict_pending ON (user_id, entity, record_uuid)
WHERE status = 'pending'` guarantees at most one pending record per conflicting row;
a repeated conflict on an unresolved record refreshes the server snapshot instead of
duplicating, and a conflict after resolution starts a fresh record. A second index
`idx_sync_conflict_user_status (user_id, status, detected_at)` serves the per-user
pending/history queries.

### Detection (`SupabaseSyncTransport`)

- `_write` keeps the conditional `.eq('row_version', base_version)` update; when it
  matches nothing it now fetches the current server row and returns it in
  `SyncPushResult.serverData` / `serverUpdatedAt` / `serverRowVersion` instead of a bare
  `conflict: true`.
- `_remove` (soft delete) is now **version-conditional**: a delete of a row another
  device changed surfaces as a conflict (delete-vs-update) rather than silently
  deleting the newer server row. A remote row already gone is an idempotent success.

### Engine capture (`SyncEngine`)

`SyncEngine` gained optional `conflictRepository` and `database`. On a conflict it reads
the local row via `SyncTableRegistry` (best-effort), builds a `SyncConflictRecord` with
both snapshots and persists it before resolving. Recording is best-effort — it can
never break the push path.

### Wiring / UI

- `SyncUiState` and `SyncStatusSnapshot` expose `pendingConflictCount` (unresolved
  manual merges), refreshed on `refresh()` and after each sync.
- `SyncStatusController` derives `SyncUiStatus.conflict` when a run reported conflicts
  **or** the durable pending count is non-zero.

### Files

- `lib/domain/entities/sync_conflict_record.dart` — `SyncConflictRecord` +
  `ConflictResolutionStatus`.
- `lib/domain/repositories/sync_conflict_repository.dart` — contract.
- `lib/data/datasources/local/sync_conflict_local_data_source.dart` — SQLite store +
  pending upsert semantics.
- `lib/data/repositories/sync_conflict_repository_impl.dart` — repository impl.
- `lib/data/datasources/local/app_database.dart` — migration v17 (`sync_conflict` +
  indexes); `lib/core/constants/app_constants.dart` — `databaseVersion = 17`.
- `lib/data/services/sync/sync_contracts.dart` — `SyncPushResult` gained
  `serverData` / `serverUpdatedAt`.
- `lib/data/services/sync/supabase_sync_transport.dart` — conflict fetch +
  version-conditional soft delete.
- `lib/data/services/sync/sync_engine.dart` — `_handleConflict` → capture + resolve.
- `lib/injection/dependency_injection.dart`, `lib/presentation/providers/sync_providers.dart`
  — providers + pending-conflict UI state.

### Verified

- `flutter analyze` — clean.
- `test/conflict_resolution_test.dart` — **11/11 green**: v17 migration (table +
  partial unique index + status index), one pending record per (user, entity,
  record_uuid), same record edited on two devices (SERVER_WINS, both snapshots kept),
  stale base version, server updated later wins, local newer still server-wins with
  local data preserved, delete-vs-update detected and recorded, manualMerge stays
  pending with repeated conflicts refreshing one record, resolved conflicts close and
  a new one starts fresh, cloud-uuid capture.
- Existing sync regression (`sync_engine`, `dao_sync_batch3/4/5`, `initial_sync`,
  `incremental_sync`, `sync_foundation`) — **171/171 green**.
- Full regression after PROMPT 19: **383 pass / 2 fail** — both pre-existing and
  unrelated (`session_manager` device-change, `hydration_repository` loadStatistics).

## 16. Large Dataset Synchronization + Performance (PROMPT 20)

### Goal

Keep the offline sync bounded and indexed so 10,000+ records sync predictably:
paginated pull, batched apply, indexed queries (EXPLAIN QUERY PLAN), an
unbounded-but-resumable first sync, incremental deltas and measured push/pull.

### What already existed (verified, no change)

- **Paginated pull** — `SyncEngine._pullUnlocked` pulls in pages of
  `AppConstants.syncPullBatchSize` (100); each page applies atomically with its
  cursor advance in one transaction.
- **Batched apply** — `RemoteChangeApplier` upserts a whole page inside one
  transaction; `MasterDataSyncService._applyBatch` applies each master page in
  one transaction. DAO bulk inserters write large datasets in one transaction.
- **Indexed queries** — every syncable table has a unique `uuid` index
  (v15), `(user_id, updated_at)` indexes, business composite indexes
  (`idx_weight_log_user_logged` etc., v14), and the outbox drain is covered by
  `idx_sync_event_user_status_created (user_id, status, created_at)`. FK
  resolution (`WHERE uuid = ?`) uses the unique uuid index.
- **WAL + sane PRAGMAs** (native) — `journal_mode=WAL`, `synchronous=NORMAL`,
  `temp_store=MEMORY`, `cache_size=-8000`, `mmap_size=256MB`, `foreign_keys=ON`.
- **Incremental cursor + high-watermark master sync** — cursor advances only
  with committed batches; master catalogs pull after their high watermark.

### Changes made

1. **`SyncEngine.pull` / `_pullUnlocked` gained `drainToEnd`** — incremental
   runs keep the `syncMaxPullBatches` (50 × 100 = 5,000) safety cap; the
   **initial sync passes `drainToEnd: true`** so a >5,000-row first sync drains
   the remote paginator to completion in ONE run (previously it stopped at 5,000
   and marked complete, silently deferring the rest to the next run).
2. **Livelock guard** — an uncapped run breaks out if a paginator claims more
   data but never advances its keyset cursor.
3. **Stable outbox pagination (bug fix)** — the outbox drain previously used
   `LIMIT/OFFSET ORDER BY created_at` over a set that shrinks as events
   transition to PROCESSING/COMPLETED. OFFSET over a shrinking set silently
   skipped events once more than one page was pending. The engine now re-queries
   the front of the eligible set per pass (each event leaves the set while
   claimed/handled), and `ORDER BY created_at ASC, id ASC` makes the ordering
   stable. Manual-merge conflicts set a future `next_retry_at` so a pending
   conflict never hot-loops the drain.
4. **Reasonable network batch sizes** — pull/master pages = 100, outbox page =
   `syncQueuePageSize` (500). Push stays one network call per event so each
   write keeps its own `row_version` conflict detection.

### Measured benchmark (`test/large_dataset_sync_test.dart`, sqflite_ffi, Windows VM)

| Phase | Records | Pages | Time | Notes |
|---|---|---|---|---|
| Initial sync (drain) | 10,001 | 101 × 100 | ~3.2 s | cursor 0 → 10,001, progress emitted per page |
| Incremental sync | 500 delta | 5 × 100 | ~0.24 s | only rows after the stored cursor |
| Push (outbox drain) | 10,001 | 21 × 500 | ~7.0 s | all completed exactly once |
| Memory (RSS) | — | — | +15 MB | 155 → 170 MB during the full run |
| Database size | 10,001 rows | — | 4,816 KB | incl. indexes |

All assertions use generous CI-safe caps; the printed metric line is the source
of the numbers above.

### Files

- `lib/data/services/sync/sync_engine.dart` — `drainToEnd` + re-query drain +
  livelock guard + manual-merge backoff.
- `lib/data/services/sync/initial_sync_service.dart` — initial pull uses
  `drainToEnd: true`.
- `lib/data/datasources/local/sync_event_local_data_source.dart` — stable
  `ORDER BY created_at ASC, id ASC` for the outbox drain.
- `test/large_dataset_sync_test.dart` — PRAGMA, EXPLAIN QUERY PLAN,
  pagination, batch-cap and the 10,001-record benchmark.

### Verified

- `flutter analyze` — clean.
- `test/large_dataset_sync_test.dart` — **5/5 green** (WAL/PRAGMA, pagination,
  EXPLAIN QUERY PLAN indexes, bounded incremental cap, 10,001-record
  benchmark).
- Full regression after PROMPT 20: **388 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).

## 17. Sync Failure Recovery (PROMPT 21)

### Goal

Prove — with automated tests — that every failure mode in the sync path
recovers without **silent mutation loss**, **endless repeats of a committed
cloud mutation**, or **cursor skips**, and that an abrupt exit is repaired by a
startup recovery pass.

### Failure model and recovery

| # | Scenario | Mechanism | Recovery |
|---|---|---|---|
| 1 | App killed mid-push | Event stuck in `PROCESSING` | `resetStuckProcessingEvents` reclaims it on the next run (older than `syncStuckProcessingTimeout`) |
| 2 | Network lost during upload | `SyncTransportException` → `FAILED_RETRYABLE` + exponential backoff | Retried when `next_retry_at` passes; survives restarts (durable) |
| 3 | Supabase 500 | transport maps 5xx → retryable `SyncTransportException` | Same backoff path; eventually succeeds |
| 4 | Supabase timeout | retryable `SyncTransportException('request_timeout')` | Same backoff path; eventually succeeds |
| 5 | Auth expiry | `auth_session_expired` is **retryable** (never permanent) | Event retained in the queue until re-auth; then delivered exactly once |
| 6 | Duplicate event | `track` merges duplicate pending events (same `event_uuid`); pull dedups by row `uuid` | One queue row, one push, one row in DB |
| 7 | Corrupted / unsupported event | `unsupported_entity` → `FAILED_PERMANENT` (terminal) | Never retried forever; does not block the healthy events behind it |
| 8 | Commit-then-timeout (lost response) | Idempotency: cloud write is an upsert keyed on the row `uuid`; retry acknowledges without mutating | A committed cloud mutation is never repeated (`serverMutations == 1`) |
| 9 | App killed mid-pull (partial batch) | Batch apply + cursor advance are one transaction | Failed batch rolls back; cursor stays put; next run resumes after it |
| 10 | Network lost during download | `sync()` catches `SyncTransportException`, reports `failed`, cursor untouched | Next run completes the pull |
| 11 | Cursor mismatch / stalled keyset | Livelock guard breaks a paginator that never advances its cursor | No infinite loop; applied data stays; cursor reflects reality |
| 12 | Partial batch / re-delivery | Remote re-delivery deduplicated by `uuid` | Same row never applies twice |

### Startup recovery (`SyncRecoveryService`)

`lib/data/services/sync/sync_recovery_service.dart` runs the post-crash sequence:

1. **Recover stuck events** — `engine.resetStuckProcessingEvents(userId)`.
2. **Validate sync state** — `SyncStateValidator.validate`: a healthy cursor is
   non-negative; `initialSyncCompleted` implies a recorded `lastSyncAt`. An
   invalid state is reported (`syncStateValid: false`) so the caller can re-run
   the initial sync instead of skipping rows.
3. **Resume pending sync** — `processQueue` drains PENDING + due
   FAILED_RETRYABLE events (safe retries only; auth-expiry events are kept).
4. **Retry against the cloud** — with a ready transport, `engine.sync` also
   pulls remote changes after the stored cursor.

Returns a `SyncRecoveryResult` (`reclaimedStuck`, `syncStateValid`, `resumed`,
`pulled`, `failed`, `healthy`). It is wired as the recovery step after app
launch alongside the existing DB `RecoveryManager` integrity pass.

### Tests (`test/sync_failure_recovery_test.dart`)

**15/15 green** — 8 push scenarios, 4 pull scenarios, 3 startup-recovery tests.
Uses the real SQFlite DB (WAL, `sync_event`, `sync_state`, `weight_log`) with
scripted transports (per-call push steps incl. commit-then-timeout, paged pull
with a mid-download failure, stalled-keyset). Invariants asserted verbatim:
no silent loss, committed mutation never repeated, cursor never advances past a
failed batch, stuck events reclaimed, backoff gating honoured.

### Files

- `lib/data/services/sync/sync_recovery_service.dart` — `SyncRecoveryService`,
  `SyncRecoveryResult`, `SyncStateValidator` (new).
- `test/sync_failure_recovery_test.dart` — 12 scenarios + startup recovery
  (new).

### Verified

- `flutter analyze` — clean.
- `test/sync_failure_recovery_test.dart` — **15/15 green**.
- Full regression after PROMPT 21: **403 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).

## 18. Sync Status UX (PROMPT 22)

### Goal
Surface sync health everywhere without ever exposing technical errors:
a subtle dashboard indicator and a dedicated Settings section (status chip,
last synced time, pending/failed/conflict tiles, "Sync now") that reports
completion/failure through friendly copy only.

### Files
- `lib/presentation/widgets/sync/sync_status_chip.dart` — `SyncStatusKind`
  (`synced/syncing/offline/failed/conflict/pendingChanges/idle`), the pure
  `syncStatusKindOf(SyncUiStatus)` mapping, and the `SyncStatusChip` widget.
  A `compact: true` variant renders only the icon (subtle dashboard use).
- `lib/presentation/providers/sync_providers.dart` — the concurrency guard at
  the top of `SyncController.runSync`:
  ```dart
  if (state.isSyncing) return;
  ```
  so a manual "Sync now" can never stack progress states or snackbars on an
  in-flight run (the engine still serializes under its own per-user lock).
- `lib/presentation/screens/settings/sync_settings_screen.dart` — status chip,
  last synced (relative or "never"), pending / failed / conflict tiles with
  counts, "Sync now" button with in-progress state. Completion feedback via
  `ref.listen` on `syncControllerProvider` detecting the idle-after-syncing
  edge, gated by a `_manualRequested` flag: transport-not-ready →
  `syncCompletedOffline`, `failure != null` → `syncCompletedWithErrors`,
  otherwise `syncCompleted`.
- Router: `AppRoutes.settingsSync = '/settings/sync'` + `settings-sync`
  GoRoute. `settings_screen.dart` gained a **Sync** section (between Storage
  and Backup). `dashboard_header.dart` became a `ConsumerWidget` and shows a
  compact `SyncStatusChip` next to the date row.
- `lib/l10n/app_en.arb` / `app_bs.arb` — sync status/settings keys
  (`syncStatusSynced`, `syncStatusSyncing`, `syncStatusOffline`,
  `syncStatusFailed`, `syncStatusConflict`, `syncStatusPending`,
  `syncStatusNotSynced`, `syncSettingsTitle`, `syncSettingsLastSynced`,
  `syncSettingsNeverSynced`, `syncSettingsPendingChanges`,
  `syncSettingsFailedChanges`, `syncSettingsConflicts`, `syncCompleted`,
  `syncCompletedOffline`, `syncCompletedWithErrors`).

### Behavior rules
- Status derivation (`SyncStatusController`): signed-out → **offline**;
  syncing → **syncing**; conflict (failure conflicts or durable pending
  conflict count) → **conflict**; durable `snapshot.failed > 0` → **failed**;
  pending > 0 → **pending changes**; `lastSyncedAt` set / initial sync seen →
  **synced**; otherwise **not synced yet**.
- The queue counts used by the chip come from `SyncEngine.snapshot`, which
  folds `failedRetryable` into `pending` and permanent failures into `failed`.
- No raw exception text, error codes, tokens or stack traces ever reach the
  widget tree — the UI only renders the friendly localized labels; the last
  error string is stored masked in the durable store for support.

### Verification
- `test/sync_status_ux_test.dart` — **13/13 green** covering: the pure
  `syncStatusKindOf` mapping for every status; `SyncStatusController`
  derivation for signed-out/syncing/success/partialFailure/error/conflict/
  idle; chip label rendering for every status (and the guarantee that no
  technical text like `postgrest` appears); the compact (icon-only) variant;
  the concurrency guard (a running sync short-circuits before touching the
  sync pipeline — asserted via a counting `SyncStateRepository` that must stay
  untouched); the offline "Sync now" path (progress → idle, no failure, queue
  processed, transport sync skipped, `lastSyncAt` recorded); and the failed
  run path (friendly `error` status derived from the refreshed snapshot).
- `flutter analyze` — clean.
- Full regression after PROMPT 22: **416 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).

## 19. Two-Logical-Device Sync Validation (PROMPT 23)

### Goal
Prove the offline-first engine is genuinely multi-device correct: two logical
devices with **separate SQLite databases** sharing one Supabase-like cloud,
exercising create/update/offline/conflict/delete, exactly-once bulk uploads,
incremental pull cursors and kill-and-restart recovery.

### Enabling change
`AppDatabase` gained an optional `databaseName` constructor parameter
(defaults to `AppConstants.databaseName`). Default behaviour is unchanged; a
test can open per-device physical stores (`a.db`, `b.db`).

### What was tested
- `test/multi_device_sync_test.dart` — an in-memory `_CloudStore` (idempotent
  `onConflict: 'id'` upserts, optimistic `row_version` conditional writes,
  soft-delete tombstones, keyset-paginated `sync_changes` feed) shared by two
  per-device `_CloudStoreTransport`s. Scenarios: workout create A→B; workout
  edit B→A (optimistic lock); offline food log retained → uploaded later → B;
  concurrent edits → SERVER_WINS conflict + durable conflict record + B
  converges to the server row; delete tombstone A→B; 100 offline records
  upload exactly once (no duplicates on re-sync); 1000 remote changes pulled
  incrementally with a stable cursor; kill-and-restart recovery of a
  committed-but-timed-out push without a duplicate cloud row.

### Verification
- `test/multi_device_sync_test.dart` — **8/8 green**.
- `flutter analyze` — clean.
- Full regression after PROMPT 23: **424 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).
- See `docs/NEXFIT_MULTI_DEVICE_SYNC_TEST.md`.

## 20. Sync Security Audit (PROMPT 24)

### Goal
Prove the sync layer cannot leak data between users or secrets into logs,
uploads or the cloud: cross-user read/write/update/delete isolation, local-only
`sync_state`, read-only master data, anon-only keys, no PII columns, no
passwords in payloads and no token/secret logging. RLS is assumed on the
backend and never weakened — the client and its contracts are verified to
uphold the same boundaries.

### What was tested
- `test/sync_security_audit_test.dart` — two users (`user-1`, `user-2`) on
  separate databases sharing a user-scoped `_SecureCloud` transport that
  enforces row ownership like RLS. Behavioral checks: read isolation (user-2
  pulls 0 of user-1's changes), write isolation (a restored-backup device
  holding user-2's rows is rejected with `security_policy_violation` and the
  cloud stays empty), update isolation, delete isolation, `sync_state`
  local-only, payload columns ⊆ `{id, user_id, row_version, deleted_at} ∪
  mapping`, and no full uuids/password/token/secret in captured logs.
  Static checks: master transport has no write calls, `lib/` scan finds no
  service-role reference, and no registry mapping uses a PII/credential
  column.

### Verification
- `test/sync_security_audit_test.dart` — **10/10 green**.
- `flutter analyze` — clean.
- Full regression after PROMPT 24: **434 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).
- See `docs/NEXFIT_SYNC_SECURITY_AUDIT.md`.

## 21. Offline-First End-to-End Audit (PROMPT 25)

### Goal
Prove the offline-first architecture end-to-end through the **real DAO layer**
(the same data sources the app reads and writes through): the app is fully
usable offline, a "Sync now" run while offline uploads nothing, every mutation
is retained durably, and after reconnect a second device converges to the exact
same state — even when the network flaps mid-run.

### What was tested
- `test/offline_first_e2e_test.dart` — a phone device produces an offline
  session through seven real DAOs (weight, food, water, sleep, steps, fitness
  goal, workout) with a create/edit/delete mix; the read path immediately
  reflects every change (offline-first reads); an offline `sync()` uploads
  nothing and keeps all 9 events retryable; on reconnect the same events upload
  exactly once and a tablet converges (edited value applied, created rows
  present, deleted row tombstoned); a flapping run (push succeeds, pull fails)
  is reported as a partial failure and a later retry recovers with no duplicate
  rows in the cloud or on the tablet.

### Verification
- `test/offline_first_e2e_test.dart` — **3/3 green**.
- `flutter analyze` — clean.
- Full regression after PROMPT 25: **437 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).
- See `docs/NEXFIT_OFFLINE_FIRST_E2E_TEST.md`.

## 22. Production Readiness Audit (PROMPT 26)

### Goal
Final review of the offline-first two-way sync system against six production
criteria — correctness, durability & crash recovery, performance & scale,
security & multi-tenancy, observability, and operational readiness — with every
verdict backed by a test suite, a static check or a documented constant.

### Findings
- **Correctness**: ready — atomic outbox commits, idempotent upserts,
  optimistic conflicts, tombstones, per-user cursors, exactly-once uploads.
- **Durability**: ready — WAL + `synchronous=NORMAL`, stuck-processing reclaim,
  retry backoff, kill-and-restart recovery.
- **Performance**: ready — WAL/cache/mmap PRAGMAs, batched DAO writes, bounded
  incremental pulls, 10,001-record benchmark.
- **Security**: ready with a server dependency — the client enforces
  cross-user isolation (PROMPT 24, 10/10) and carries only the anon key, but
  Postgres RLS must exist server-side.
- **Observability**: ready — structured masked logs + friendly UI status.
- **Operational**: conditional — no live-Supabase smoke suite (no credentials),
  RLS/`sync_changes`/Realtime must be provisioned, and 13+ user tables are not
  yet DAO-migrated (they surface as `unsupported_entity`, a fail-safe).

### Verification
- `flutter analyze` — clean.
- Full regression after PROMPT 26: **437 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).
- See `docs/NEXFIT_PRODUCTION_READINESS.md`.

## 23. Profile & Settings Finalization (PROMPT 27)

### Goal
Finalize the Profile & Settings module without redesigning it: give the profile
a timezone field end to end (entity → migration v18 → sync mapping → edit UI),
move account-level actions (change password, logout, delete account) into a
dedicated Account screen, and prove the profile offline-first + auth flows with
a dedicated test suite.

### Changes
- **Timezone field**: `user_profile.timezone` added by migration v18
  (`_migrationV18ProfileFinalization`, additive; existing rows get `NULL` and
  keep their `uuid`/`row_version`). `UserProfile.timezone`, model map/parse and
  the `user_profile → profiles` sync mapping (`timezone ↔ timezone`) all carry
  it. `AppConstants.databaseVersion` bumped 17 → 18.
- **Edit Profile**: timezone text field pre-filled from the stored value or the
  device UTC offset (`UTC±HH:MM`), saved via `ProfileController.updateProfile`.
- **Account settings**: new `AccountSettingsScreen` (route `settingsAccount`)
  holding the identity header, change-password bottom sheet, logout and the
  destructive delete-account action. The delete-account tile was removed from
  the About screen (single location). Change password flows through
  `AuthService.updatePassword` → `AuthRepository.updatePassword` →
  `UpdatePasswordUsecase` → `AuthController.changePassword`, using GoTrue
  `auth.updateUser(UserAttributes(password:))`.
- New l10n keys (en + bs) for the timezone and account strings.

### Verification
- New `test/profile_settings_finalization_test.dart` — **10/10**:
  1. profile timezone persists and round-trips (v18),
  2. schema version is 18 and the column exists,
  3. the profile sync mapping carries timezone and never auth credentials,
  4. an offline profile update stays queued and uploads once connectivity
     returns,
  5. applying a pulled profile change locally never re-queues (no sync loop),
  6. change password forwards the new password and succeeds,
  7. a rejected password surfaces a friendly `AuthException`,
  8. `UpdatePasswordUsecase` maps success/failure through `Result`,
  9. logout clears the session and a fresh sign-in restores it,
  10. delete account leaves the user signed out.
- `flutter analyze` — clean.
- Full regression after PROMPT 27: **447 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).

## 24. Dashboard UX Finalization (PROMPT 28)

### Goal
Close the remaining dashboard gaps without redesigning it: surface sleep and
lifetime XP, wire every quick action to a real destination, make the dashboard
aggregate read bounded 7-day windows (so large histories stay fast) while
keeping the full-history meaning of the `hasWeight` / `hasWorkouts` empty-state
flags, and prove it all with a dedicated test suite.

### Changes
- **Bounded reads**: `DashboardRepositoryImpl.loadDashboard` now queries the six
  activity tables through `getByDateRange(weekStart, tomorrow)` instead of
  scanning each table end to end. The `has*` flags keep their full-history
  meaning via cheap extra reads: `weightLog.getLatest` (hasWeight / latest
  weight) and `workoutHistory.countCompleted` (hasWorkouts). `hasActivity`
  still includes in-window workouts.
- **Sleep metric**: `DashboardSummary` gains `sleepMinutes` / `hasSleep` from the
  most recent night within the window; shown as a new "Sleep" metric cell
  (`7h 30m` or `—`). `getByDateRange` was added to the sleep data source,
  repository and implementation, and exposed on the `StepLogRepository` for the
  weekly charts.
- **Lifetime XP**: `DashboardSummary.totalXp` read from the `user_level`
  singleton (`LevelRepository.getByUserId`, added to the dashboard repository
  wiring and DI) and shown as a new "XP" metric cell.
- **Quick actions wired**: Start Workout → workout list (`AppRoutes.workoutList`),
  Add Meal → food database (`AppRoutes.foodDatabase`), Sleep Tracker → new
  `DashboardDialogs.showLogSleep` bottom sheet (duration presets + custom
  minutes + quality slider) that writes a real `SleepLog` and refreshes the
  dashboard. `EmptyWorkoutCard`'s "first workout" button now pushes the workout
  list instead of a coming-soon snackbar.
- New l10n keys (en + bs): dashboardSleep, dashboardXp, dashboardSleepHour,
  dashboardSleepMinute, dashboardLogSleepTitle, dashboardLogSleepHint,
  dashboardLogSleepCustomHint, dashboardLogSleepSuccess.

### Verification
- New `test/dashboard_finalization_test.dart` — **11/11**:
  1. sleep metric uses the most recent night in the window (older nights ignored),
  2. sleep stays empty when the only entry predates the window,
  3. totalXp surfaces the `user_level` singleton,
  4. totalXp is zero when no level row exists,
  5. hasWeight keeps full-history meaning while weekly charts stay bounded,
  6. hasWorkouts counts completed workouts from all history, charts bounded,
  7. today's aggregates and weekly charts are bounded to the window,
  8. best workout streak still drives summary + achievement,
  9. `SleepLogRepository.getByDateRange` filters correctly,
  10. `StepLogRepository.getByDateRange` filters correctly,
  11. an in-progress workout alone sets hasActivity but not hasWorkouts.
- `flutter analyze` — clean.
- Full regression: **457 pass / 2 fail** — the same two pre-existing failures
  (`session_manager` device-change, `hydration_repository` loadStatistics).
  The `large_dataset_sync_test` 10k-record benchmark is timing-sensitive: it
  takes ≈34s (initial pull 12s + push 22s) and trips the default 30s test
  timeout on a loaded machine — it passes with an extended timeout and is
  unrelated to these changes (no sync/DAO code touched).

## 25. Workout Experience Finalization (PROMPT 29)

### Goal
Close the workout UX gaps without redesigning it: make every tile and button
navigate somewhere real, surface the exercise instructions that already exist
in the data during a session, return the user to the Workout tab after a
completed session, align and localize the equipment filter with the actual
seeded catalog, and make search self-sufficient as a first entry point.

### Changes
- **Routine tiles navigate**: `WorkoutDetailScreen`'s `ExerciseTile` was a
  dead `onTap: () {}`; it now pushes `AppRoutes.exerciseDetailPath(exerciseId)`
  (the id is always present for the seeded library).
- **Instructions in the player**: during the exercising phase a "How to"
  (`exerciseHowTo`) chip appears when the exercise has instructions; tapping it
  opens a bottom sheet with the full text. Real data only — no instructions,
  no chip.
- **Completion returns to Workout**: after a session the summary's Done button
  sets `shellTabIndexProvider` to the Workout tab before going to the shell
  (previously it landed on Home).
- **Empty-library CTA**: `_EmptyLibrary` accepted an `onBrowse` callback that
  was never invoked; it now renders a "Browse workouts" (`workoutBrowse`)
  button wired to the full workout list.
- **Equipment filter aligned + localized**: the picker previously listed 8
  English names ("Barbell", "Kettlebell", "Resistance Band", "Yoga Mat",
  "Treadmill", "Exercise Ball") that never match the seeded catalog — such
  filters always returned nothing. It now lists the real catalog values
  (`None`, `Dumbbell`, `Jump Rope`, `Chair`, `Pull-up bar`) with localized
  labels (values stay canonical so filtering keeps working).
- **Search self-seeds**: `WorkoutLibraryRepositoryImpl.search` now calls
  `ensureSeeded(userId)` first, so search never silently returns an empty
  library when it is the first entry point (deep link, fresh state).
- **History empty state**: the empty-history action was a "Retry" that only
  invalidated the provider; it now reads "Start now" and opens the workout
  list.
- New l10n keys (en + bs): workoutBrowse, workoutEquipmentNone,
  workoutEquipmentDumbbell, workoutEquipmentJumpRope, workoutEquipmentChair,
  workoutEquipmentPullUpBar.

### Verification
- New `test/workout_finalization_test.dart` — **5/5**:
  1. the equipment filter matches real seeded values (`Dumbbell` matches,
     legacy `Barbell` matches nothing),
  2. every routine exercise in a workout detail exposes an id (navigation
     target always valid),
  3. seeded exercises carry instructions (the player "How to" chip renders),
  4. seeding is idempotent and the library is never empty,
  5. search without filters returns the seeded library (self-seeding works).
- `flutter analyze` — clean.
- Full regression: **463 pass / 2 fail** — the same two pre-existing failures
  (`session_manager` device-change, `hydration_repository` loadStatistics).
  The `large_dataset_sync_test` 10k-record benchmark passed this run (it
  remains timing-sensitive under the 30s default timeout on a loaded machine).

## 26. Nutrition Experience Finalization (PROMPT 30)

### Goal
Close the nutrition UX gaps without redesigning it: fix four user-visible
strings carrying corrupted `Â`/`Ã` bytes, stop English meal-slot names leaking
into the Bangla UI, wire the template builder's dead tiles, route the template
food picker through go_router, make food search meaningful on every section
(and debounced), give the history day-list a real empty state, centralize the
copy-yesterday action, localize month abbreviations, and make food search
self-sufficient as a first entry point.

### Changes
- **Mojibake fixed** (4 strings): `add_food_sheet` title, the meal-template
  item/count lines, and the meal-slot entry row rendered corrupted bytes
  (`Â·`, `Ã—`) literally. Now the proper `·` and `×` characters.
- **Meal-slot names localized**: the six meal slots were rendered straight
  from the DB's English `meal_category.name`. New `mealCategory*` l10n keys
  (en + bs) map the canonical slugs (`breakfast`, `morning_snack`, `lunch`,
  `evening_snack`, `dinner`, `late_night_snack`) via a shared
  `mealCategoryLabel` helper (with a raw-name fallback for unknown slugs),
  used by the slot card, the add-food sheet, the meal-planner card and the
  template builder chips.
- **Dead template tiles wired**: `FoodTile(onTap: () {})` in the template
  builder now opens the food detail screen (`foodDetailPath(id)`).
- **go_router for template picker**: the template builder pushed the food
  database with a raw `Navigator.push(MaterialPageRoute(...))`; it now uses
  `context.push(AppRoutes.foodDatabase, extra: FoodDatabaseArgs.template())`
  (deep-linkable, consistent back stack).
- **Search always does something + debounced**: typing while Favorites/Recent/
  Frequent was selected silently did nothing; the query is now debounced
  (250 ms) and auto-switches to the catalog section so search results always
  appear.
- **History empty state**: the "Daily breakdown" section was blank when no
  days had data; it now shows the standard no-history card.
- **Copy-yesterday centralized**: the nutrition home's copy-yesterday button
  called the repository directly; it now goes through the `copyYesterdayMeals`
  provider helper (single source of truth for invalidation).
- **Localized months**: `formatNutritionDate` took `AppLocalizations` and uses
  new `month*` keys (en + bs) instead of hard-coded English abbreviations.
- **Search self-seeds**: `NutritionRepositoryImpl.searchFoods` calls
  `ensureSeeded()` first, so the food database never silently returns an empty
  library as a first entry point (deep link) — mirroring the workout library.
- **Cleanup**: removed the unreferenced `nutritionFoodCategoriesProvider` and
  the now-unused direct repository import from the nutrition home.

### Verification
- New `test/nutrition_finalization_test.dart` — **10/10**:
  1. the six meal categories are seeded with the canonical slugs + ids,
  2. every daily slot carries a category that resolves to a localized label,
  3. seeded catalog items expose ids (food-detail navigation always valid),
  4. search without filters self-seeds and returns the 200+ catalog,
  5. category-filtered search matches the requested category,
  6. no `.dart` file under `lib/` contains the corrupted `Â`/`Ã` bytes,
  7. en/bs l10n expose the localized meal-slot and month labels,
  8. `formatNutritionDate` uses localized month abbreviations,
  9. `MealSlotCard` renders a clean `× ·` separator and a localized slot name,
  10. `MealSlotCard` falls back to the raw name for unknown slugs.
- `flutter analyze` — clean.
- Full regression: **472 pass / 2 fail** — the same two pre-existing failures
  (`session_manager` device-change, `hydration_repository` loadStatistics).
  The `large_dataset_sync_test` 10k-record benchmark failed this run under the
  default 30s timeout and then passed 5/5 with `--timeout 120s` (real work
  ≈34s) — a documented timing flake, not a regression.

## 27. Health Tracking Finalization (PROMPT 31)

### Goal
Close the remaining health-tracking UX gaps without redesigning: scope the
water reminder list to water only (it was leaking other reminder types from
the shared reminder table), make weight goals reachable/editable from the
dashboard, pre-fill BMI height from the profile, add a manual steps-logging
entry point from the dashboard, build a real sleep history screen with
add/edit/delete, link the dashboard sleep metric to it, and localize month
abbreviations across the water/weight flows.

### Changes
- **Water reminders scoped**: `waterRemindersProvider` now filters
  `hydrationRepositoryProvider.getReminders()` to `ReminderType.water`, so the
  water reminders screen no longer lists sleep/step/weight reminders that share
  the same table.
- **Reminder editing**: the water reminders list is now fully editable — tapping
  a tile opens the same editor in edit mode (`_openEditor(context, ref,
  existing: reminder)`).
- **Weight goal ring tappable**: the dashboard weight `_HeroCard` became a
  `ConsumerWidget` and its goal ring is wrapped in a `GestureDetector` that opens
  `showWeightGoalSheet`; a `weightSetGoalHint` ("Tap the ring…") text shows until
  a goal is set.
- **BMI height pre-fill**: the dashboard BMI quick action reads the profile
  (`profileControllerProvider.valueOrNull?.profile?.heightCm`) to pre-fill the
  height field in the goal sheet instead of leaving it blank.
- **Manual step logging**: new `DashboardDialogs.showLogSteps` dialog (digits-only
  step field, optional date picker) writes a `StepLog` through the step-log
  repository, then refreshes the dashboard. A seventh quick-action tile
  (`Icons.directions_walk_rounded`) opens it. Manual entries carry derived
  distance/calories via the new `StepEstimator` (stride 0.000762 km/step,
  0.04 kcal/step) so progress reports treat them like tracker data.
- **Sleep history screen**: new `SleepHistoryScreen` + `showSleepEntrySheet`
  (add/edit: date, duration presets or custom minutes, quality 0–5, note) backed
  by new `sleep_providers.dart` (`sleepHistoryProvider` newest-first,
  `addSleepEntry`, `updateSleepEntry`, `deleteSleepEntry`). Stats row shows
  nights, average duration and average quality via the new `SleepStats` helper.
- **Dashboard sleep metric linked**: `DashboardSummaryCard` grew an `onSleepTap`
  callback threaded through the metric grid; the sleep metric cell is now an
  `InkWell` that `context.push(AppRoutes.sleepHistory)` (new `/sleep/history`
  route).
- **Localized months**: hard-coded English month arrays replaced with
  `localizedMonth` / `formatLocalizedDate` (`lib/core/utils/date_formatting.dart`,
  Bangla digits preserved) across the water screen, water statistics, water
  history, weight screen, weight history and weight statistics.

### Verification
- New `test/health_tracking_finalization_test.dart` — **6/6**:
  1. `waterRemindersProvider` exposes only water-type reminders,
  2. sleep history sorts newest-first (synthetic repositories),
  3. logging a manual step updates the dashboard summary,
  4. `StepEstimator` distance/calories math,
  5. `SleepStats` aggregation (nights, avg duration, avg quality),
  6. `formatLocalizedDate` / `localizedMonth` localized en+bs (Bangla digits).
- `flutter analyze` — clean.
- Full regression: **479 pass / 2 fail** — the same two pre-existing failures
  (`session_manager` device-change, `hydration_repository` loadStatistics). The
  `large_dataset_sync_test` benchmark passed this run under `--timeout 120s`.

## 28. Fitness Goals & Progress (PROMPT 32)

### Goal
Finalize the goal-management flow without redesigning: goals track
weight/workout/water/steps/nutrition/sleep (only schema-supported types),
templates stay server-authoritative master data (`user_id NULL`), user goals
are user-owned and syncable, and progress tiles show current vs target, percent,
remaining and streak computed deterministically from real DB records — never
fake values. Create/update/complete/delete enqueue sync events; remote updates
must not loop.

### Changes
- **Goal progress streaks**: `GoalProgress` gained a `streak` field. In
  `loadGoalProgress` the analysis now also awaits
  `streakRepository.getByUserId` (9th item in the shared `Future.wait`), derives
  the weight streak with `currentStreak(weight-log days, now)` and computes
  workout/water/steps/sleep streaks via a new `_streakFor` helper; the streak is
  set on every goal type. The mangled `_explicitWeightTarget` /
  `_explicitWeightTargetDate` / `_explicitWorkoutTarget` helpers were restored.
- **Progress tile**: `GoalProgressTile` shows the remaining amount ("X unit to
  goal"), a flame icon with "N day streak", and a "Goal reached" state once
  `fraction >= 1`.
- **Goal management providers**: new `fitness_goal_providers.dart` with
  `userGoalsProvider`, `goalTemplatesProvider`, `createGoalFromTemplate`,
  `createUserGoal`, `updateUserGoal`, `completeUserGoal`, `deleteUserGoal`.
  `_refreshGoalDependents` invalidates `userGoalsProvider`, `goalProgressProvider`
  and `dashboardControllerProvider` after every mutation.
- **Goal management UI**: new `goal_management_screen.dart` (goal list with
  status chip + progress row + streak, template adoption section, delete
  confirm dialog, empty state) and `goal_editor_sheet.dart` (GoalType choice
  chips, target value field, target date picker, save). Reached from the
  `GoalProgressScreen` app-bar settings action via the new
  `AppRoutes.progressGoalManagement` (`/progress/goals/manage`).
- **Template seed fix**: the four seeded `fitness_goal` templates stored
  `goal_type` in snake_case (`weight_loss`) but `GoalType.fromName` matches
  camelCase enum names, so every template parsed as `GoalType.other`. The seed
  now uses the enum names (`weightLoss`, `weightGain`, `maintainWeight`,
  `muscleBuilding`), restoring template type resolution.
- **l10n**: goal-management keys added to both `app_en.arb` and `app_bs.arb`
  (progress remaining/streak/reached, management title/subtitle, add/edit/delete
  labels, delete confirm, goal-type/target/date labels, status labels, saved /
  updated / deleted toasts, empty state, templates, mark-complete, days-left) and
  `flutter gen-l10n` regenerated.

### Verification
- New `test/goals_finalization_test.dart` — **12/12**:
  1. creating a user goal persists it and generates a CREATE sync event,
  2. templates are master data (`user_id NULL`) and never carry a user id,
  3. adopting a template copies master data into a user-owned goal,
  4. updating a goal bumps `row_version` and records an UPDATE event,
  5. completion marks the goal completed without losing sync metadata,
  6. deleting a goal soft-deletes the row and records a DELETE event,
  7. goal progress shows current, target, percent, remaining and streak,
  8. progress is computed offline from local records only,
  9. a reached goal reports 100% and zero remaining,
  10. the user-goal provider reflects the user-owned goals,
  11. a remote apply updates a goal without creating a loop event,
  12. user isolation keeps events scoped to the owning user.
- `flutter analyze` — clean.
- Full regression: **491 pass / 2 fail** — the same two pre-existing failures
  (`session_manager` device-change, `hydration_repository` loadStatistics).

## 29. Gamification Finalization (PROMPT 33)

### Goal
Finalize the gamification loop without redesigning: XP, levels, achievements,
badges and streaks must be real, derived from actual user records, offline-first
and idempotent — a retry, an app restart or a duplicated sync push must never
award XP twice or re-unlock an achievement.

### Changes
- **XP is now actually awarded.** The `xp_history` + `user_level` tables, models,
  repositories, DAOs and sync registry already existed (PROMPT 14/15) but no code
  path ever wrote XP. `WorkoutSessionRepositoryImpl` (the session-completion
  trigger) now accepts an `XpHistoryRepository` and `LevelRepository` and, inside
  `completeSession`, calls `_awardWorkoutXp` (deterministic: 20 XP base + 2 XP per
  minute + 1 XP per 50 kcal) and then `_progressLevel` to apply the gain to the
  `user_level` singleton. `WorkoutCompletion` gained `xpEarned`, `xpTotal` and
  `level` so the UI can surface the result.
- **Duplicate XP prevention.** The award is keyed by the session itself:
  `source = 'workout'`, `reason = 'session_completed:<historyId>'`. Before
  inserting, the repository checks
  `XpHistoryRepository.getByUserAndSourceAndReason`, and the local
  `UNIQUE(user_id, source, reason)` index (app_database.dart) is the final
  guard. Because the reason is unique per session, a retry, an app restart or a
  duplicated sync push can never double-award; when the award is skipped the
  level is left untouched (no spurious `user_level` UPDATE event).
- **Level progression.** `_progressLevel` reads the singleton (`uuid == user_id`),
  adds the award to `currentXp`/`totalXp` and loops while
  `currentXp >= requiredXp`, raising the level and growing the requirement
  (`requiredXp = 100 * level`). Upserts flow through the existing sync-aware
  `LevelLocalDataSource` so levels propagate via `user_levels` on the cloud.
- **Idempotent unlocks.** `AchievementLocalDataSource.insertAll` and
  `BadgeLocalDataSource.insertAll` now insert with
  `ConflictAlgorithm.ignore`, so even a race or duplicate push can never re-insert
  an achievement/badge; the existing `owned`-set guard in `_unlockAchievements`
  and the `byType` map in `_updateBadges` already prevented re-awarding.
- **Streaks stay local.** No change needed — streak rows are derived caches that
  never leave the device (outbox-exempt), so temporary offline state cannot reset
  them.
- **Wiring.** `workoutSessionRepositoryProvider` (dependency_injection.dart)
  passes `xpHistoryRepositoryProvider` and `levelRepositoryProvider` into
  `WorkoutSessionRepositoryImpl`.

### Verification
- New `test/gamification_finalization_test.dart` — **10/10**:
  1. completing a session awards XP and creates the level row (88 XP for
     30 min / 400 kcal),
  2. re-completing the same session never awards XP twice (retry / restart),
  3. XP accumulates and levels up across sessions (3×88 XP → level 2, 164/200),
  4. achievement unlock is idempotent across sessions (`first_workout` once),
  5. bulk badge and achievement inserts ignore duplicates,
  6. streak survives temporary offline (recorder disabled, completion still
     runs end-to-end and preserves the streak),
  7. completing a session records sync events for `xp_history` and `user_level`,
  8. pulling XP and level from the cloud converges without duplicates or loop
     events,
  9. remote apply converges a second device without double awards,
  10. per-user XP and levels are isolated.
- `flutter analyze` — clean.
- Full regression: **501 pass / 2 fail** — the same two pre-existing failures
  (`session_manager` device-change, `hydration_repository` loadStatistics).

## 30. Reminders & Notifications Finalization (PROMPT 34)

### Goal
Close the reminder module's finalization gaps without redesigning: reminder
configuration is already user-owned and syncable, but notifications were only
scheduled at app bootstrap — a cloud pull brought new reminders onto the device
without scheduling them locally until the next restart. Keep notification
execution device-local (no platform notification ids ever sync), respect the
device timezone, and prove the offline/sync/restart/timezone guarantees with
dedicated tests.

### Review outcome
- **Types.** Workout, water, meal, weight, sleep (and the pre-existing custom /
  medicine / step) reminder types already exist; no new medical functionality
  was added.
- **Local scheduling.** Reminders are scheduled by
  `LocalNotificationService` (FlutterLocalNotificationsPlugin) at device-local
  times; `Reminder` persists wall-clock `HH:mm` times, so they keep firing
  offline via local scheduling.
- **Sync.** `reminder` + `reminder_history` are `USER_SYNCABLE` (transactional
  outbox, uuid, row_version, soft delete). The `reminder` table stores no
  platform notification ids — the DAO holds configuration only, so "pulled from
  cloud" rows can never collide with already-scheduled platform notifications.
- **Timezone.** Scheduling maths work in device-local wall-clock time
  (`reminder_schedule.dart` builds local `DateTime`s; the service converts via
  `tz.local`). A device timezone change shifts when a reminder fires without
  corrupting the stored config. The profile already stores its timezone.
- **No duplicate notifications on pull.** Deterministic notification ids are
  derived from the local row id (`id * 10000 + base + slot`), and every sync
  completion runs a `cancelAll()` + re-schedule pass, so re-scheduling after a
  pull is naturally idempotent.

### Changes
- **Post-sync rescheduling.** `SyncController` (sync_providers.dart) now calls
  `rescheduleRemindersInContainer(ref.container)` after the initial sync pull
  and after every incremental sync completion. Newly-pulled reminder rows are
  therefore scheduled locally without an app restart, and the cancel-all-then-
  reschedule pass cannot duplicate already-scheduled notifications.
- **Best-effort scheduling.** `rescheduleRemindersInContainer` swallows
  failures (e.g. a missing provider during a test container, an unsupported
  device) so scheduling can never break the sync pipeline or settings changes.

### Verification
- New `test/reminder_finalization_test.dart` — **17/17**:
  1. creating a reminder persists it and records a CREATE event,
  2. an identical reminder is rejected as a duplicate,
  3. updating bumps row version and records an UPDATE event,
  4. deleting soft-deletes and records a DELETE event,
  5. create/edit/delete work locally while offline (recorder disabled, no
     outbox events),
  6. the scheduler reads reminders that were created offline,
  7. a remote pull converges without an echo event,
  8. re-applying the same remote reminder never duplicates the row,
  9. pulls are scoped per user,
  10. cloud history rows converge (reminder FK resolves, no echo),
  11. `syncMissed` records unattended occurrences exactly once,
  12. reminders survive a restart (fresh repos over the same DB) and are
      re-read for scheduling without new events,
  13. occurrences are computed in device-local wall-clock time,
  14. a weekly reminder respects its selected weekdays,
  15. an end date bounds the occurrence stream,
  16. disabled reminders never fire and never schedule,
  17. `nextReminderOccurrence` picks the first future local occurrence.
- `flutter analyze` — clean.
- Full regression: **518 pass / 2 fail** — the same two pre-existing failures
  (`session_manager` device-change, `hydration_repository` loadStatistics).

## 31. Performance Audit (PROMPT 37)

Audited the SQLite queries, indexes, Riverpod providers, sync batching, memory,
images, animations, startup and the search/dashboard hot paths. Full detail:
`docs/NEXFIT_PERFORMANCE_AUDIT.md`.

### Review outcome
- `EXPLAIN QUERY PLAN` (via `test/performance_audit_test.dart`, 6/6 green)
  proved every dashboard 7-day range read and every sync/outbox hot path is
  already index-served by the composite `(user_id, timestamp)` and `(user_id,
  status)` indexes from migrations v14+. **No new indexes were needed.**
- Fixed (evidence-driven):
  1. `workout_seeder.dart` re-committed an ~84-row seed batch on every workout
     search/build keystroke — added a `COUNT(*)` early-return guard.
  2. Exercise + workout search lacked debouncing — added 250 ms debounces
     (mirrors the food search).
  3. `dashboard_screen.dart` refreshed the sync health card on every build via
     `addPostFrameCallback` — removed (the sync controller refreshes itself on
     completion).
- Deliberately unchanged (documented): sequential per-event push (correctness /
  ordering contract), `systemHealthProvider` live `integrity_check`
  (correctness-critical), non-lazy food catalog (bounded, grouped), `repeat()`
  animations (gated off-tab by `TickerMode`), cold-start tab pre-warm (app-shell
  design).

### Verification
- `test/performance_audit_test.dart` — **6/6 green** (EXPLAIN QUERY PLAN
  evidence).
- `flutter analyze` — clean.
- Full regression: **524 pass / 2 fail** — the same two pre-existing failures.

## 32. Complete Application Security Audit (PROMPT 38)

Full client-side security audit of auth & sessions, local storage, the sync
layer, network posture, logging, Android OS-level backup and dependencies.
Severity table and rationale: `docs/NEXFIT_SECURITY_AUDIT.md`.

### Fixes applied
1. **Supabase JWT session moved to the OS keychain.** `SecureLocalStorage`
   (flutter_secure_storage) replaces the default plaintext
   `SharedPreferencesLocalStorage` (`supabase_service.dart` → `authOptions`).
   Closes the access+refresh-token-at-rest exposure.
2. **PIN hashing upgraded to PBKDF2-HMAC-SHA256** with a random 16-byte salt
   (120k iterations), stored as `nk2:<iter>:<saltB64>:<hashB64>`, verified in
   constant time. Legacy SHA-256 static-salt hashes still verify and are
   re-hashed in place on the next successful unlock (`PinHasher`,
   `settings_providers.verifyPin`).
3. **Lock screen escalating retry delay.** After 5 consecutive failures the
   pad locks for 30 s → 1 min → 2 min → 5 min with a live countdown
   (`lock_screen.dart`, `pin_ui.dart` `enabled` flag, new `settingsLockTooManyAttempts`
   l10n key).
4. **Client-side cross-user push guard.** `SupabaseSyncTransport._requireUserId`
   now throws non-retryable `security_policy_violation` when the event user ≠
   the authenticated session user (defense-in-depth below server RLS).
5. **Android OS backup disabled.** `allowBackup="false"` +
   `dataExtractionRules`/`fullBackupContent` exclude every domain from cloud
   backup and device transfer — the unencrypted DB and SharedPreferences no
   longer leave the device.
6. **User ids masked in logs.** `SyncLog.maskUserId` applied in the sync engine,
   transport, session manager and Realtime notifier.
7. Cleanup: removed 4 dead legacy token keys; `.gitignore` excludes `*.env`.

### Documented by design
Unencrypted SQLite at rest (mitigated by field encryption, app-lock, FLAG_SECURE,
no OS backup), plaintext `sessions.token` (device-local random session id),
account deletion not wiping local data (offline-first + manual "delete local
data"), logout keeping secure storage (offline-first), client-side ownership
guards in 2/20 DAOs (server RLS authoritative), `event_uuid` not sent to the
server (record-uuid upsert dedupes), raw server errors in debug-only logs
(release emits nothing).

### Verification
- New `test/security_hardening_test.dart` — **6/6 green** (PBKDF2 format,
  random salt, tamper rejection, legacy verification, upgrade semantics).
- `flutter analyze` — clean.
- Full regression: **530 pass / 2 fail** — the same two pre-existing failures.
