# NexFit — SQLite Migration v15 DDL Review (Design Only)

> **Status: REVIEW — nothing implemented.**
> No Dart code was changed. No migration was written or executed. Supabase is
> untouched. `SyncEngine` / `SyncTransport` / `SyncEventRecorder` are untouched.
>
> This document designs the exact **SQFlite migration v15** required for the
> offline-first two-way sync foundation. It is the prerequisite the phase audit
> identified: the local schema currently uses `INTEGER PRIMARY KEY AUTOINCREMENT`
> ids with no stable cloud identity, no `updated_at` on most tables, no
> `deleted_at`, no `row_version`, no cursor store and no outbox identity fields.
>
> Every statement below is derived from the **actual** schema in
> `lib/data/datasources/local/app_database.dart` (migrations v1–v14, version 14),
> cross-checked against the deployed Supabase schema
> (`supabase/migrations/001_initial_nexfit_schema.sql`).

---

## 1. Exact list of the 31 syncable tables

Determined from the actual `CREATE TABLE` statements in `app_database.dart`.

### 1.1 The 31 user-owned syncable tables (`USER_SYNCABLE`)

| # | Local table | Cloud table | Local PK |
|---|---|---|---|
| 1 | `user_profile` | `profiles` | `user_id TEXT` |
| 2 | `fitness_goal` | `fitness_goals` | `id INT` |
| 3 | `workout` | `workouts` | `id INT` |
| 4 | `exercise` (custom rows) | `exercises` | `id INT` |
| 5 | `workout_exercise` | `workout_exercises` | `id INT` |
| 6 | `workout_history` | `workout_history` | `id INT` |
| 7 | `exercise_history` | `exercise_history` | `id INT` |
| 8 | `meal` | `meals` | `id INT` |
| 9 | `food_item` (custom rows) | `foods` | `id INT` |
| 10 | `food_log` | `food_logs` | `id INT` |
| 11 | `water_log` | `water_logs` | `id INT` |
| 12 | `weight_log` | `weight_logs` | `id INT` |
| 13 | `bmi_log` | `bmi_logs` | `id INT` |
| 14 | `body_measurement` | `body_measurements` | `id INT` |
| 15 | `sleep_log` | `sleep_logs` | `id INT` |
| 16 | `step_log` | `step_logs` | `id INT` |
| 17 | `reminder` | `reminders` | `id INT` |
| 18 | `achievement` | `user_achievements` | `id INT` |
| 19 | `badge` | `user_badges` | `id INT` |
| 20 | `streak` | `streaks` | `id INT` |
| 21 | `daily_progress` | `daily_progress` | `id INT` |
| 22 | `app_settings` | `user_settings` | `id INT` (`user_id` UNIQUE) |
| 23 | `exercise_favorite` | `exercise_favorites` | `(user_id, exercise_id)` |
| 24 | `food_favorite` | `food_favorites` | `(user_id, food_item_id)` |
| 25 | `meal_item` | `meal_items` | `id INT` |
| 26 | `reminder_history` | `reminder_history` | `id INT` |
| 27 | `xp_history` | `xp_history` | `id INT` |
| 28 | `user_level` | `user_levels` | `id INT` |
| 29 | `challenge` | `user_challenges` | `id INT` |
| 30 | `milestone` | `challenge_milestones` | `id INT` |
| 31 | `reward` | `user_rewards` | `id INT` |

### 1.2 Excluded (not part of the 31)

| Table | Class | Why excluded |
|---|---|---|
| `users` | LOCAL_ONLY | Auth identity; replaced by Supabase `auth.users`; kept for local FK integrity |
| `calorie_log` | LOCAL_ONLY (derived) | Recomputable from `food_log`/`exercise_history`; **no cloud table exists** |
| `backup_history` | LOCAL_ONLY | Device-local backup log |
| `sync_event` | SYNC_METADATA | The outbox itself — altered, not syncable |
| `error_logs` | LOCAL_ONLY | Diagnostics |
| `sessions` | LOCAL_ONLY | Local security |
| `schema_migrations` | internal | Migration bookkeeping |
| `workout_category` | MASTER_DATA | Global catalog, keyed by `slug`; pulled, never uploaded |
| `meal_category` | MASTER_DATA | Global catalog, keyed by `slug`; pulled, never uploaded |

---

## 2. Current schema summary

- **DB version:** `AppConstants.databaseVersion = 14`.
- **Migration mechanism:** `AppDatabase` runs a `_migrations` list; each
  `DatabaseMigration.version` is applied inside one `db.transaction` and recorded
  in `schema_migrations`. v15 must be appended to that list and the constant
  bumped to `15`.
- **PK style:** almost all user tables are `id INTEGER PRIMARY KEY AUTOINCREMENT`
  plus a `user_id TEXT NOT NULL` FK to `users(id)`. Exceptions:
  - `user_profile` — PK is `user_id TEXT` (== auth.uid() == cloud `profiles.id`).
  - `exercise_favorite` / `food_favorite` — composite PK `(user_id, x_id)`.
- **Timestamp convention:** epoch **milliseconds** INTEGER via `ModelCodec.epochMs`.
- **Missing timestamps:** `workout_exercise`, `exercise_history`, `meal_item`
  have **no `created_at` and no `updated_at`**; `user_profile` and `app_settings`
  have `updated_at` but **no `created_at`**.
- **No sync metadata anywhere:** no table has `uuid`, `deleted_at`, or
  `row_version`. Only a handful have `updated_at` (see §9 matrix).
- **Child tables without `user_id`:** `workout_exercise`, `exercise_history`,
  `meal_item` (user owned transitively via their parent FK).
- **`sync_event`** already has `status`, `retry_count`, `conflict_strategy`,
  `payload`, `created_at`, `updated_at`, `synced_at`, `last_error` — but **no**
  `event_uuid`, `device_id`, `base_version`.
- **Existing indexes:** v2 + v14 index sets (e.g. `idx_weight_log_user_logged`,
  `idx_sync_event_user_status_created`) are preserved; v15 only adds new ones.

---

## 3. Proposed schema after v15

Every `USER_SYNCABLE` table gains **four** sync metadata columns:

```sql
uuid          TEXT,                      -- stable cross-device cloud identity (nullable in DDL, always set by the app + backfill; UNIQUE index)
updated_at    INTEGER,                   -- epoch ms, server-comparable revision clock (backfilled where missing)
deleted_at    INTEGER,                   -- soft-delete tombstone (epoch ms) or NULL
row_version   INTEGER NOT NULL DEFAULT 0 -- optimistic concurrency counter
```

Exceptions and additions:

| Table | Extra change |
|---|---|
| `user_profile` | `uuid` backfilled from `user_id`; `created_at` added (nullable) |
| `app_settings` | `uuid` backfilled from `user_id` (singleton per user); `created_at` added (nullable) |
| `workout_exercise` | also add `user_id TEXT` + `created_at INTEGER` (backfilled from parent `workout`) |
| `exercise_history` | also add `user_id TEXT` + `created_at INTEGER` (backfilled from parent `workout_history`) |
| `meal_item` | also add `user_id TEXT` + `created_at INTEGER` (backfilled from parent `meal`) |
| `exercise` / `food_item` | hybrid — `uuid` on **all** rows (master + custom) for uniform mapping; master rows keep `user_id NULL` |

New `sync_state` table (single per-user cursor):

```sql
CREATE TABLE sync_state (
  user_id                TEXT PRIMARY KEY NOT NULL,
  cursor                 INTEGER NOT NULL DEFAULT 0,   -- cloud sync_changes.id high-water mark
  initial_sync_completed INTEGER NOT NULL DEFAULT 0,
  last_sync_at           INTEGER,
  status                 TEXT,                          -- optional: 'idle'|'syncing'|...
  master_versions        TEXT,                          -- optional JSON: {catalog: data_version}
  updated_at             INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
)
```

`sync_event` additions:

```sql
ALTER TABLE sync_event ADD COLUMN event_uuid   TEXT;      -- idempotency key (set once, reused on retry)
ALTER TABLE sync_event ADD COLUMN device_id    TEXT;      -- device origin (from SessionManager device id)
ALTER TABLE sync_event ADD COLUMN base_version INTEGER;   -- row_version the mutation was based on
ALTER TABLE sync_event ADD COLUMN next_retry_at INTEGER;  -- optional: scheduler backoff timestamp
```

---

## 4. Exact SQL statements that would be executed

> Formatting note: the migration is Dart code (`db.execute`), so `$now` below is a
> Dart epoch-ms value captured once. SQLite `ALTER TABLE ADD COLUMN` cannot add a
> `NOT NULL` or `UNIQUE` column directly, so `uuid` is added nullable and
> uniqueness is enforced with a `UNIQUE` index (§14). All ALTERs run **inside the
> existing `db.transaction`** that `_applyPendingMigrations` already provides.

### 4.1 Create `sync_state`

```sql
CREATE TABLE sync_state (
  user_id                TEXT PRIMARY KEY NOT NULL,
  cursor                 INTEGER NOT NULL DEFAULT 0,
  initial_sync_completed INTEGER NOT NULL DEFAULT 0,
  last_sync_at           INTEGER,
  status                 TEXT,
  master_versions        TEXT,
  updated_at             INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### 4.2 `sync_event` additions

```sql
ALTER TABLE sync_event ADD COLUMN event_uuid TEXT;
ALTER TABLE sync_event ADD COLUMN device_id TEXT;
ALTER TABLE sync_event ADD COLUMN base_version INTEGER;
ALTER TABLE sync_event ADD COLUMN next_retry_at INTEGER;
```

### 4.3 Per-table sync metadata columns

Group **A — tables that already have `updated_at`** (add `uuid`, `deleted_at`,
`row_version`): `fitness_goal`, `workout`, `meal`, `reminder`, `badge`, `streak`,
`daily_progress`, `user_level`, `challenge`, `milestone`, `reward`.

```sql
ALTER TABLE <table> ADD COLUMN uuid TEXT;
ALTER TABLE <table> ADD COLUMN deleted_at INTEGER;
ALTER TABLE <table> ADD COLUMN row_version INTEGER NOT NULL DEFAULT 0;
```

Group **B — tables with `created_at` but no `updated_at`** (add `uuid`,
`updated_at`, `deleted_at`, `row_version`): `exercise`, `food_item`, `food_log`,
`water_log`, `weight_log`, `bmi_log`, `body_measurement`, `sleep_log`, `step_log`,
`achievement`, `exercise_favorite`, `food_favorite`, `reminder_history`,
`xp_history`, `workout_history`.

```sql
ALTER TABLE <table> ADD COLUMN uuid TEXT;
ALTER TABLE <table> ADD COLUMN updated_at INTEGER;
ALTER TABLE <table> ADD COLUMN deleted_at INTEGER;
ALTER TABLE <table> ADD COLUMN row_version INTEGER NOT NULL DEFAULT 0;
```

Group **C — child tables with no `user_id`, no `created_at`, no `updated_at`**
(add `user_id`, `uuid`, `created_at`, `updated_at`, `deleted_at`, `row_version`):
`workout_exercise`, `exercise_history`, `meal_item`.

```sql
ALTER TABLE <table> ADD COLUMN user_id TEXT;
ALTER TABLE <table> ADD COLUMN uuid TEXT;
ALTER TABLE <table> ADD COLUMN created_at INTEGER;
ALTER TABLE <table> ADD COLUMN updated_at INTEGER;
ALTER TABLE <table> ADD COLUMN deleted_at INTEGER;
ALTER TABLE <table> ADD COLUMN row_version INTEGER NOT NULL DEFAULT 0;
```

Group **D — singleton tables with `updated_at` but no `created_at`** (`uuid`,
`created_at`, `deleted_at`, `row_version`): `user_profile`, `app_settings`.

```sql
ALTER TABLE <table> ADD COLUMN uuid TEXT;
ALTER TABLE <table> ADD COLUMN created_at INTEGER;
ALTER TABLE <table> ADD COLUMN deleted_at INTEGER;
ALTER TABLE <table> ADD COLUMN row_version INTEGER NOT NULL DEFAULT 0;
```

> `workout_history` is in Group B. `user_profile` gets `uuid = user_id` and
> `app_settings` gets `uuid = user_id` during backfill (§5).

---

## 5. Existing-data migration strategy

Order of operations inside the v15 transaction (SQLite DDL is transactional):

1. `CREATE TABLE sync_state`.
2. `ALTER TABLE sync_event` (4 columns).
3. All per-table ALTERs (groups A–D above).
4. **Backfill `uuid`** — a Dart loop per table using a v4 generator
   (`Random.secure()`, ~20-line helper; no new dependency unless approved):

   ```dart
   // per table, using raw rowid to avoid composite-key assumptions
   final rows = await db.rawQuery('SELECT rowid AS _r FROM <table> WHERE uuid IS NULL');
   for (final row in rows) {
     await db.rawUpdate(
       'UPDATE <table> SET uuid = ? WHERE rowid = ?',
       [generateUuidV4(), row['_r']],
     );
   }
   // special cases
   UPDATE user_profile SET uuid = user_id WHERE uuid IS NULL;
   UPDATE app_settings  SET uuid = user_id WHERE uuid IS NULL;
   ```

5. **Backfill `updated_at`** (Group B/C/D only), preserving known order:
   `UPDATE <table> SET updated_at = created_at WHERE updated_at IS NULL;`
   For child tables (Group C) without `created_at`, backfill from the parent:
   `UPDATE workout_exercise SET created_at = COALESCE((SELECT created_at FROM workout WHERE workout.id = workout_exercise.workout_id), $now) WHERE created_at IS NULL;` and similarly `updated_at = created_at`. `user_profile`/`app_settings` `created_at = $now`.
6. **Backfill `user_id` on child tables** from their parent:
   ```sql
   UPDATE workout_exercise SET user_id = (SELECT user_id FROM workout WHERE workout.id = workout_exercise.workout_id) WHERE user_id IS NULL;
   UPDATE exercise_history SET user_id = (SELECT user_id FROM workout_history WHERE workout_history.id = exercise_history.workout_history_id) WHERE user_id IS NULL;
   UPDATE meal_item SET user_id = (SELECT user_id FROM meal WHERE meal.id = meal_item.meal_id) WHERE user_id IS NULL;
   ```
7. Create indexes (§14).
8. `schema_migrations` records version 15 (handled by the framework).

All statements are idempotent-guarded (backfill predicates `WHERE ... IS NULL`)
so a partial failure never double-assigns or corrupts.

---

## 6. UUID generation strategy

- **Format:** RFC 4122 v4 (string, lowercase, hyphenated), generated **once**.
- **When:** at local row creation (in the DAO, next phase) and once during the
  migration for existing rows.
- **Persistence:** stored in the new `uuid` column. Never recomputed on read.
- **Survives:** app restart, migration, sync, logout/login, future updates —
  because it is a column, not a runtime artifact.
- **Mapping:** local `uuid` == cloud row `id` (both client-generated v4). The
  sync transport upserts `on conflict (id) do update` keyed by `uuid`; the pull
  applier matches cloud `id` to local `uuid`.
- **Singletons:** `user_profile.uuid = user_id`, `app_settings.uuid = user_id`
  (their cloud PKs are already stable identities — `profiles.id == auth.uid()`
  and `user_settings.user_id == auth.uid()`).
- **Hybrid tables** (`exercise`, `food_item`): master rows also get a `uuid`
  (matches the cloud catalog row id); custom rows get their own.
- **NOT NULL semantics:** DDL column is nullable only because SQLite cannot add a
  `NOT NULL` column via `ALTER`. Uniqueness is enforced by index; non-null is
  enforced at the app layer on every insert. Backfill guarantees existing rows are
  non-null. Documented as an accepted trade-off (§17).

---

## 7. `updated_at` strategy

- **Representation:** epoch milliseconds INTEGER (matches `ModelCodec`).
- **Existing:** already present on the Group A + D tables; kept as-is.
- **Added** to Group B/C tables and backfilled from `created_at` (best available
  estimate of last change); child tables fall back to parent `created_at`, then `$now`.
- **Semantics:** `updated_at` is the **server-comparable** revision clock. The
  cloud maintains its own `updated_at timestamptz` via trigger; the app pushes
  the local value and prefers the server value after a successful push/pull so
  clocks stay aligned.
- **Maintenance:** `updated_at`/`row_version` are bumped in the DAO write path
  (next phase); v15 does **not** add SQLite triggers (app-managed is the existing
  convention — the app already writes `created_at`/`updated_at` by hand).

---

## 8. `deleted_at` strategy

- **Representation:** epoch milliseconds INTEGER, `NULL` = alive, non-null = soft-deleted.
- **Added** to all 31 tables (uniform; simple).
- **Why:** pull must apply remote tombstones without physically losing locally
  queued data; cloud sync model is tombstone-based (`deleted_at` + `sync_changes`
  DELETE entries).
- **Caveat:** `profiles` on the cloud has **no** `deleted_at` (account deletion =
  `auth.users` cascade). The local `user_profile.deleted_at` column is harmless
  and simply unused; the app must not soft-delete `user_profile`.
- **Physical cleanup:** deferred; hard deletes remain a later cleanup job.

---

## 9. `row_version` strategy

- **Type/default:** `INTEGER NOT NULL DEFAULT 0`.
- **Initial value for existing records:** `0`. This is the safe baseline: no
  production sync has occurred, so no local row has a known server revision.
  Treating it as 0 means the first push is a `create`/`upsert` that the server
  accepts and starts tracking (`row_version` is server-incremented on each
  UPDATE via trigger; INSERT keeps 0). Nothing is wrongly overwritten.
- **Increment:** on every local update the DAO sets `row_version = row_version + 1`
  (next phase) — never on read.
- **Server ↔ local mapping:** after a successful push, the returned server
  `row_version` is written back to the local row; after a pull, the pulled
  `row_version` is written locally. `base_version` on a sync event is the local
  `row_version` captured *before* the increment (see §13).

---

## 10. `sync_state` design

```sql
CREATE TABLE sync_state (
  user_id                TEXT PRIMARY KEY NOT NULL,   -- one row per authenticated user
  cursor                 INTEGER NOT NULL DEFAULT 0,  -- cloud sync_changes.id high-water mark
  initial_sync_completed INTEGER NOT NULL DEFAULT 0,
  last_sync_at           INTEGER,
  status                 TEXT,                        -- optional lifecycle metadata
  master_versions        TEXT,                        -- optional JSON {catalog: data_version}
  updated_at             INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

- **Per-user, not global:** `PRIMARY KEY(user_id)` guarantees isolation — the
  cursor for user A can never leak into user B's pull.
- **Single cursor:** the cloud `sync_changes` uses one monotonic `id` for all
  user-owned tables, so one integer cursor per user is correct (not per-entity).
- **`master_versions`:** a JSON map (`{ 'exercise': 3, 'food': 5, ... }`) of the
  last-applied `master_data_versions.data_version` per catalog, so master sync
  can detect changes without a second table.
- **`initial_sync_completed`:** distinguishes first-run full pull from
  incremental pulls.
- Survives restart/logout/login because it is a table row keyed by user.

---

## 11. `sync_event` changes

Current table (v13) → after v15:

| Column | Existing | Added |
|---|---|---|
| `id`, `user_id`, `entity`, `entity_id`, `operation` | ✓ | — |
| `payload`, `status`, `retry_count`, `conflict_strategy` | ✓ | — |
| `created_at`, `updated_at`, `synced_at`, `last_error` | ✓ | — |
| `event_uuid` | — | ✓ idempotency key |
| `device_id` | — | ✓ device origin |
| `base_version` | — | ✓ conflict base |
| `next_retry_at` | — | ✓ optional backoff scheduler |

No existing column is duplicated or removed; `status` will gain
`processing`/`failed_retryable`/`failed_permanent` **values** (code-only, TEXT
column, no DDL).

---

## 12. `device_id` design

- **Source of truth:** the existing stable per-install device id already
  produced by `SessionManager.getOrCreateDeviceId()` (persisted in secure
  storage under `AppConstants.deviceIdStorageKey`, 12 hex chars, `Random.secure()`).
- **Recommendation:** store `device_id` **once per sync_event row**
  (denormalized) rather than in a separate metadata table. Rationale:
  - Events must be self-contained when pushed (the transport needs the origin
    device without a lookup).
  - It is a small, non-sensitive token (not a password, token or PII).
  - A separate table would force a join for no benefit; the value is immutable
    for the life of an install.
- No new table, no new dependency. `SyncEventRecorder.record` gains a `deviceId`
  parameter stamped from `SessionManager` at event creation.

---

## 13. `base_version` design

`base_version INTEGER` = the `row_version` of the record the mutation was
created against (captured before the local increment). Documented semantics:

```
Server row_version  = 5   (pulled from cloud earlier)
Local row_version   = 5   (matches server after last pull)
User edits locally
  DAO writes row_version = 6
  sync event base_version = 5, row_version = 6
Server is already at row_version 7  →  server compares base_version (5) != 7
  → conflict detected (report, no automatic merge in this phase)
```

- `create` events use `base_version = 0`.
- After a successful push, the server's new `row_version` is written back
  locally so the next mutation starts from the correct base.
- `base_version` + `event_uuid` together make the push **idempotent and
  conflict-detectable**: the same event_uuid re-applies the same logical
  mutation; a mismatched base_version signals a concurrent write.

---

## 14. Required indexes

New indexes (all `IF NOT EXISTS`); existing v2/v14 indexes are preserved.

Per user table (unique uuid — replaces nothing):

```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_<table>_uuid ON <table>(uuid);
CREATE INDEX IF NOT EXISTS idx_<table>_user_updated ON <table>(user_id, updated_at);
```

For `user_profile` / `app_settings` (single-row-per-user; `user_updated` on
`user_id` only):

```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profile_uuid ON user_profile(uuid);
CREATE UNIQUE INDEX IF NOT EXISTS idx_app_settings_uuid ON app_settings(uuid);
```

For `exercise` / `food_item` (hybrid; master rows have NULL user_id — a plain
`(user_id, updated_at)` index is still useful for custom rows):

```sql
CREATE INDEX IF NOT EXISTS idx_exercise_user_updated ON exercise(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_food_item_user_updated ON food_item(user_id, updated_at);
```

`sync_event`:

```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_event_event_uuid ON sync_event(event_uuid);
CREATE INDEX IF NOT EXISTS idx_sync_event_device ON sync_event(device_id);
```

> `idx_sync_event_user_status_created` (v14) already covers the status-cursor
> path; no duplicate. `sync_state` PK covers `user_id`; no extra index.

---

## 15. Migration order

1. `CREATE TABLE sync_state`
2. `ALTER TABLE sync_event` (4 columns)
3. Per-table ALTERs — **groups A–D** (§4.3)
4. Backfill `uuid` (§5 step 4)
5. Backfill `updated_at` / `created_at` (§5 step 5)
6. Backfill child-table `user_id` (§5 step 6)
7. Create indexes (§14)
8. Framework records version 15

Order matters only for backfills (columns must exist before their `UPDATE`);
ALTERs themselves are order-independent. Everything runs in one transaction.

---

## 16. Foreign-key considerations

- Existing FKs are **unchanged** — v15 adds columns only, never drops/recreates a
  table, so `PRAGMA foreign_keys = ON` behavior is untouched.
- New `user_id` on child tables is **plain TEXT (no FK)** — SQLite cannot add an
  FK via `ALTER TABLE ADD COLUMN`, and adding one would require table rebuild
  (§18). Non-null + correctness is enforced at the app layer; orphan risk is nil
  because child rows are only created/updated through their parent DAO.
- `sync_state.user_id` FK → `users(id) ON DELETE CASCADE` matches the existing
  per-user cascade pattern; a deleted account clears its cursor.

---

## 17. Failure / rollback considerations

- **Transactional:** the entire v15 migration runs inside the existing
  `db.transaction` (SQLite DDL is transactional). A failure mid-way rolls back
  all ALTERs, backfills and the `schema_migrations` insert, leaving the DB at
  version 14. This is the strongest rollback SQLite offers.
- **No table recreation:** v15 uses `ALTER TABLE ADD COLUMN` only. This
  minimizes the failure surface (no data copy, no FK re-wiring, no index rebuild
  of existing indexes). Rationale for NOT rebuilding: every table has 10–40
  columns and 1–2 FKs; recreation would risk data loss and break FK integrity
  checks for zero functional benefit.
- **Backfill guards:** every `UPDATE ... WHERE x IS NULL` is idempotent-safe.
- **Web caveat:** `sqflite_common_ffi_web` supports `ALTER TABLE`; no special
  handling needed, but v15 should be smoke-tested on the web target before
  release.
- **Resume safety:** because v15 runs in one transaction, a crash cannot leave a
  half-applied migration. If the transaction somehow commits before the
  `schema_migrations` row write (not expected — same transaction), the version
  guard in `_applyPendingMigrations` treats pending as not-applied; ALTERs are
  idempotent via `IF NOT EXISTS`/duplicate detection on the column-add side is
  NOT automatic in SQLite — so the framework's atomic transaction is the real
  protection. Documented risk: do not manually re-run v15 SQL outside the
  framework.

---

## 18. Compatibility with existing app code

- **Schema consumers:** all DAO models (`*Model.toMap/fromMap`) currently ignore
  the new columns — v15 is additive, so existing `INSERT`/`UPDATE`/`SELECT`
  statements remain valid (new columns are NULL/0 until the DAO writes them).
- **Reads:** DAO `SELECT *` returns the new columns; models that map strictly
  (known keys only) ignore them. Mappers are extended in the next phase.
- **Uniqueness:** adding `idx_<table>_uuid` has zero effect on existing writes
  because existing DAOs never set `uuid`; the sync-phase DAO updates will.
- **`user_profile` / `app_settings`:** `INSERT OR REPLACE` semantics unchanged;
  added `created_at` is NULL for existing rows (harmless).
- **Child tables** gain `user_id` — existing INSERTs omit it (NULL) until the
  sync-phase DAO populates it; parent-scoped queries (joins) still work.
- **`sync_event`:** `SyncEventModel.toMap` must add the new fields or they stay
  NULL; existing queue rows keep working. This is next-phase work.
- **`SyncEngine` / `SyncTransport` / `SyncEventRecorder`:** unchanged in v15.
  They consume the new columns/table in the following phase.

---

## 19. Compatibility with Supabase schema

| Local (v15) | Supabase (001) | Mapping |
|---|---|---|
| `uuid TEXT` (v4, unique) | `id uuid primary key` (client-generated v4) | push: `upsert on conflict (id)`; pull: match `id`→`uuid` |
| `user_id TEXT` | `user_id uuid references auth.users(id)` | push: `auth.uid()` guard; RLS `with check` re-validates |
| `updated_at INTEGER` (epoch ms) | `updated_at timestamptz` (trigger-maintained) | convert both directions; prefer server value |
| `deleted_at INTEGER` | `deleted_at timestamptz` | tombstone apply on pull; `sync_changes` DELETE entries |
| `row_version INTEGER` | `row_version bigint` | local counter mirrors server counter; server increments on UPDATE |
| `sync_state.cursor` | `sync_changes.id` (bigint identity) | `WHERE user_id = :uid AND id > cursor ORDER BY id LIMIT n` |
| `sync_state.master_versions` | `master_data_versions.data_version` | version-compare before catalog pull |
| `sync_event.event_uuid` | (payload/idempotency) | retry-safe: same event_uuid never double-applies |
| `sync_event.base_version` | row `row_version` | conflict detection: base != server row_version |

No Supabase schema change is required by v15.

---

## 20. Risks

1. **NULL `uuid` risk (DDL-level):** the column is nullable in DDL; only app-layer
   enforcement + backfill guarantee non-null. If any DAO path ever forgets to set
   `uuid`, a new row is invisible to sync. Mitigation: enforce in the shared
   write path next phase; add a `CHECK (uuid IS NOT NULL)`-style validation in
   tests. (SQLite cannot add NOT NULL via ALTER without table rebuild.)
2. **`updated_at` backfill fidelity:** Group B/C tables get `updated_at =
   created_at`, which overestimates "last modified" for rows edited after
   creation. Since no cloud sync has run yet, this is safe — the first push uses
   the real server `updated_at` afterwards. Acceptable.
3. **`user_profile` has no cloud `deleted_at`:** soft-deleting a profile locally
   would be ignored by the cloud (which cascades on account deletion). The app
   must never soft-delete `user_profile`. Documented in §8.
4. **Single cursor vs per-entity:** one `sync_changes` cursor per user is
   correct for the current cloud schema but couples all user tables to one
   cursor — a large table backlog delays others. Acceptable for this phase; a
   per-entity cursor is a future evolution.
5. **Child-table `user_id` backfill:** depends on parent FKs being intact. If a
   parent row is missing (should not happen — child FKs are `NOT NULL`/cascade),
   `user_id` stays NULL and the row is skipped by user-scoped sync.
6. **Web target:** `ALTER TABLE` works on `sqflite_common_ffi_web` but should be
   smoke-tested; the UUID backfill loop on large datasets is synchronous in the
   transaction and may need batching on very large installs.
7. **Migration atomicity is the only rollback:** SQLite cannot partially roll back
   individual ALTERs after the transaction commits; do not hand-edit the DB
   outside the framework.
8. **`sync_event.next_retry_at` is optional:** if omitted, backoff is derived
   from `retry_count` + `updated_at` at runtime; including the column simplifies
   the scheduler. Decision required (§22).

---

## 21. Validation queries (post-migration)

Run after v15 in a fresh/dev DB upgraded from v14 and on a new install:

```sql
-- 1. Every syncable table has uuid
SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'
  AND name NOT IN ('schema_migrations','users','calorie_log','backup_history',
                   'sync_event','error_logs','sessions') ORDER BY name;

-- 2/3. uuid present and unique per table (repeat for each of the 31)
SELECT COUNT(*) AS total, COUNT(uuid) AS with_uuid, COUNT(DISTINCT uuid) AS unique_uuid
FROM weight_log;

-- 4. updated_at present (Group B/C tables)
SELECT COUNT(*) FROM weight_log WHERE updated_at IS NULL;   -- expect 0

-- 5. deleted_at column exists
SELECT COUNT(*) FROM pragma_table_info('weight_log') WHERE name='deleted_at'; -- 1

-- 6. row_version present and defaulted
SELECT COUNT(*) FROM weight_log WHERE row_version = 0;     -- expect = total rows

-- 7. sync_state exists and is empty
SELECT COUNT(*) FROM sync_state;                            -- expect 0

-- 8. sync_event new columns
SELECT name FROM pragma_table_info('sync_event')
WHERE name IN ('event_uuid','device_id','base_version','next_retry_at'); -- 4 rows

-- 9. indexes exist
SELECT name FROM sqlite_master WHERE type='index'
  AND name IN ('idx_weight_log_uuid','idx_weight_log_user_updated',
               'idx_sync_event_event_uuid','idx_sync_event_device');

-- 10. existing row counts unchanged (compare against pre-migration counts)
SELECT COUNT(*) FROM weight_log;   -- identical to before upgrade
SELECT COUNT(*) FROM workout_history;
```

Automated check (test suite, next phase): open the upgraded in-memory DB, assert
every syncable table has the four columns, assert `uuid` uniqueness, assert
`updated_at`/`deleted_at`/`row_version` defaults, and assert pre/post row-count
equality for a seeded fixture.

---

## 22. Decisions requiring approval

| # | Decision | Options |
|---|---|---|
| 1 | **`uuid` DDL nullability** | Accept nullable-DDL + UNIQUE index + app-layer NOT NULL (recommended, no table rebuild) OR authorize table rebuild for strict NOT NULL |
| 2 | **`sync_event.next_retry_at`** | Add the column (recommended, simpler scheduler) OR derive backoff at runtime (no column) |
| 3 | **`uuid` helper** | Add a ~20-line v4 generator (`Random.secure()`) with no dependency (recommended) OR add the `uuid` package |
| 4 | **Child-table `user_id`** | Add `user_id` to `workout_exercise`/`exercise_history`/`meal_item` (recommended, cloud RLS parity) OR keep them parent-scoped and derive `user_id` at push time |
| 5 | **`master_versions` JSON in `sync_state`** | Single JSON column (recommended) OR a separate per-catalog table |
| 6 | **`status` column in `sync_state`** | Include (recommended) OR omit (track lifecycle in the provider instead) |

---

## Final response (this phase)

- **Document created:** `docs/SQFLITE_MIGRATION_V15_DDL_REVIEW.md` — review only; no code, no migration, no execution.
- **31 syncable tables** enumerated from the actual schema (§1) with per-table column requirements (§4).
- **Proposed changes:** four sync-metadata columns on all 31 tables; `sync_state` cursor table; `sync_event` gains `event_uuid`/`device_id`/`base_version` (+ optional `next_retry_at`); indexes (§14); backfill strategy (§5–§9).
- **Potential risks:** §20 (nullable-DDL uuid, `updated_at` backfill fidelity, single cursor, child `user_id` backfill, web smoke-test, transactional-only rollback).
- **Decisions needing approval:** §22 (6 items).

**STOPPED — waiting for explicit approval before writing migration v15 code,
modifying migration files, changing Dart code, or building the sync engine.**
