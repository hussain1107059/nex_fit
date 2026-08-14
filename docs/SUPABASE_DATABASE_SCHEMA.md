# NexFit — Supabase Database Schema

> **Phase 02 — Schema + RLS + Sync Metadata only.** No Flutter code was modified.
> The SQL in `supabase/migrations/001_initial_nexfit_schema.sql` is the single
> source of truth for this document.

---

## 1. Complete Table List (41 tables)

| # | Table | Kind | Purpose |
|---|---|---|---|
| 1 | `profiles` | User | App-level profile (id = `auth.users.id`) |
| 2 | `user_settings` | User | Cloud-portable preferences (singleton) |
| 3 | `user_levels` | User | Level / XP counters (singleton) |
| 4 | `fitness_goals` | User | User goals |
| 5 | `workouts` | User | User workouts |
| 6 | `workout_exercises` | User | Exercises within a workout |
| 7 | `workout_history` | User | Workout sessions |
| 8 | `exercise_history` | User | Per-set exercise logs |
| 9 | `meals` | User | Custom meal templates |
| 10 | `meal_items` | User | Foods within a meal |
| 11 | `food_logs` | User | Daily food logging |
| 12 | `water_logs` | User | Hydration entries |
| 13 | `weight_logs` | User | Weight entries |
| 14 | `bmi_logs` | User | BMI entries |
| 15 | `body_measurements` | User | Body measurements |
| 16 | `sleep_logs` | User | Sleep entries |
| 17 | `step_logs` | User | Step entries |
| 18 | `reminders` | User | Notification schedules |
| 19 | `reminder_history` | User | Reminder occurrences |
| 20 | `exercise_favorites` | User | User↔exercise join |
| 21 | `food_favorites` | User | User↔food join |
| 22 | `user_achievements` | User | Achievement unlock state |
| 23 | `user_badges` | User | Badge progress/earned state |
| 24 | `streaks` | User | Streak counters |
| 25 | `daily_progress` | User | Daily rollup |
| 26 | `xp_history` | User | XP ledger (append-only) |
| 27 | `user_challenges` | User | Challenge progress |
| 28 | `challenge_milestones` | User | Milestones within a challenge |
| 29 | `user_rewards` | User | Reward claim state |
| 30 | `exercises` | Hybrid (master + custom) | Global exercises + user custom |
| 31 | `foods` | Hybrid (master + custom) | Global foods + user custom |
| 32 | `workout_categories` | Master | 21 workout categories |
| 33 | `meal_categories` | Master | 6 meal slots |
| 34 | `goal_templates` | Master | Fitness-goal templates |
| 35 | `workout_templates` | Master | Global workout routines |
| 36 | `workout_template_exercises` | Master | Exercises in a template |
| 37 | `achievement_defs` | Master | Achievement catalog |
| 38 | `badge_defs` | Master | Badge catalog |
| 39 | `challenge_defs` | Master | Challenge catalog |
| 40 | `sync_changes` | Sync metadata | Append-only user change log |
| 41 | `master_data_versions` | Sync metadata | Per-catalog version cursor |

---

## 2. Table Classification

| Category | Tables |
|---|---|
| **User-owned (29)** | `profiles`, `user_settings`, `user_levels`, `fitness_goals`, `workouts`, `workout_exercises`, `workout_history`, `exercise_history`, `meals`, `meal_items`, `food_logs`, `water_logs`, `weight_logs`, `bmi_logs`, `body_measurements`, `sleep_logs`, `step_logs`, `reminders`, `reminder_history`, `exercise_favorites`, `food_favorites`, `user_achievements`, `user_badges`, `streaks`, `daily_progress`, `xp_history`, `user_challenges`, `challenge_milestones`, `user_rewards` |
| **Master / reference (10)** | `exercises` (global rows), `foods` (global rows), `workout_categories`, `meal_categories`, `goal_templates`, `workout_templates`, `workout_template_exercises`, `achievement_defs`, `badge_defs`, `challenge_defs` |
| **Hybrid (2)** | `exercises`, `foods` — `user_id IS NULL` = global master; `user_id = auth.uid()` = user custom |
| **Sync metadata (2)** | `sync_changes`, `master_data_versions` |
| **Local-only (SQFlite, not in cloud)** | `schema_migrations`, `users` (→ `auth.users`), `sync_event` (local queue), `error_logs`, `sessions`, `backup_history`, `calorie_log` (derived locally from logs) |

**Why `calorie_log` is excluded:** it is a derived rollup of `food_logs` +
`workout_history` + `water_logs`. Syncing a derived table would add redundant
write/conflict surface; the device recomputes it from synced source rows.

**Why `exercises`/`foods` stay hybrid instead of split:** the existing SQFlite
model already uses `user_id IS NULL` for built-ins and `user_id = <uid>` for
custom rows, and every repository query is `user_id IS NULL OR user_id = ?`.
Keeping the same shape preserves the data model concept and makes the client
mapping trivial.

---

## 3–6. Columns, Data Types, Primary Keys, Foreign Keys

See the migration SQL for the authoritative DDL. Conventions:

- **Primary keys:** `id uuid primary key default gen_random_uuid()` — client-
  generated UUIDs so the same logical row can be inserted idempotently from any
  device (required for two-way sync). Composite-key tables that the app treats
  as joins (`exercise_favorites`, `food_favorites`) got a surrogate `id uuid`
  plus a `UNIQUE (user_id, …)` constraint so the change log can reference a
  single `record_id`.
- **Auth key:** `user_id uuid not null references auth.users(id) on delete cascade`.
  `profiles` and the singletons are keyed by `user_id` (unique) or `id`.
- **Timestamps:** `timestamptz` (server clock via `now()` defaults + trigger).
  The app's local SQFlite epoch-ms INTEGERs convert on the client.
- **Enums:** `text` + `CHECK` constraints (no Postgres enum types) — easier to
  evolve and to map from Dart enums.
- **Colors:** stored as ARGB decimals, e.g. `4294937088` = `0xFF0000...`.
  `workout_categories.color` is `bigint` (not `integer`) — ARGB values exceed
  the int4 range; widened by migration `003`.
- **Booleans:** `boolean` (SQFlite 0/1 ints map on the client).
- **Dates:** `date` for calendar keys (`sleep_date`, `step_date`,
  `progress_date`, `birth_date`); `timestamptz` for instants.
- **Sync metadata columns on every syncable table:** `created_at`,
  `updated_at`, `deleted_at` (nullable), `row_version bigint`, `last_modified_by uuid`.

**Foreign key rules (with rationale):**

| Reference | Rule | Rationale |
|---|---|---|
| All `user_id` → `auth.users(id)` | `CASCADE` | Account deletion removes all user data (compliance + no orphans) |
| `profiles.id` → `auth.users(id)` | `CASCADE` | Profile lifecycle == account lifecycle |
| `workouts.category_id`, `meals.category_id`, `workout_templates.category_id`, `food_logs.meal_type_id` | `SET NULL` | Catalog categories are soft-deleted, never destroyed; don't break user rows |
| `workout_exercises.workout_id` → `workouts`, `meal_items.meal_id` → `meals`, `exercise_history.workout_history_id` → `workout_history` | `CASCADE` | Child rows are meaningless without their parent |
| `workout_exercises.exercise_id`, `exercise_history.exercise_id`, `meal_items.food_id`, `food_logs.food_id` | `SET NULL` | **Protect historical records** — logs/history survive catalog edits/removals |
| `reminder_history.reminder_id` → `reminders` | `SET NULL` | **Deliberate change vs SQFlite CASCADE** — statistics survive reminder deletion |
| `user_achievements.achievement_id`, `user_badges.badge_id`, `user_challenges.challenge_id` → defs | `RESTRICT` | Defs are soft-deleted; never physically delete while user state exists |
| `challenge_milestones.user_challenge_id` → `user_challenges` | `CASCADE` | Milestones belong to the user's challenge copy |
| `exercise_favorites.exercise_id`, `food_favorites.food_id` → catalog | `CASCADE` | Favorites join only; catalog rows are soft-deleted anyway |
| `workout_template_exercises.exercise_id` → `exercises` | `RESTRICT` | Template integrity — remove the link explicitly, not by delete |
| `workout_template_exercises.template_id` → `workout_templates` | `CASCADE` | Template children |

No circular dependencies exist.

---

## 7. Indexes (and why)

- **`(user_id, updated_at)`** on every user-owned table → serves the incremental
  pull (`rows for this user changed after X`) and common dashboard/history
  range queries in one composite index.
- **`updated_at`** on master tables → version-based catalog pull.
- **`updated_at WHERE user_id IS NULL`** on `exercises`/`foods` → master-row
  pull without scanning user rows.
- **FK columns** (Postgres does not auto-index FKs) → join/filter performance
  on `workouts.category_id`, `food_logs.food_id/meal_id/meal_type_id`,
  `meal_items.*`, `exercise_history.*`, `workout_template_exercises.*`, etc.
- **`sync_changes(user_id, id)`** → cursor query `id > :cursor AND user_id = :uid`.
- **Partial unique indexes** on `exercises`/`foods`: master rows unique by
  `name`, custom rows unique per `(user_id, name)` (see §Unique Constraints).
- **`logged_at`** on `food_logs` → nutrition history range queries.
- No indexes on `deleted_at` alone (low cardinality); it is covered by the
  `(user_id, updated_at)` scans.

---

## 8. Unique Constraints

| Table | Constraint | Note |
|---|---|---|
| `workout_categories` | `slug` unique | Stable identity for master sync |
| `meal_categories` | `slug` unique | Stable identity |
| `goal_templates` | `goal_type` unique | |
| `achievement_defs` | `achievement_type` unique | |
| `badge_defs` | `badge_type` unique | |
| `challenge_defs` | `challenge_type` unique | |
| `exercises` | partial: `name` (user_id IS NULL); `(user_id,name)` (custom) | Prevent duplicate master/custom exercises |
| `foods` | partial: `name` (user_id IS NULL); `(user_id,name)` (custom) | Prevent duplicate master/custom foods |
| `fitness_goals` | `(user_id, goal_type)` | Mirrors SQFlite UNIQUE |
| `streaks` | `(user_id, streak_type)` | Mirrors SQFlite UNIQUE |
| `daily_progress` | `(user_id, progress_date)` | Mirrors SQFlite UNIQUE |
| `user_settings` / `user_levels` | `user_id` unique | Singletons |
| `exercise_favorites` | `(user_id, exercise_id)` | |
| `food_favorites` | `(user_id, food_id)` | |
| `user_achievements` | `(user_id, achievement_id)` | |
| `user_badges` | `(user_id, badge_id)` | |
| `user_challenges` | `(user_id, challenge_id)` | |
| `challenge_milestones` | `(user_id, user_challenge_id, title)` | |
| `user_rewards` | `(user_id, type, title)` | Mirrors SQFlite UNIQUE |

**Deliberately NOT copied:** SQFlite's `UNIQUE (user_id, source, reason)` index
on `xp_history` — it would block legitimate repeated XP awards (e.g. same
"workout completed" reason on different days). The cloud ledger has no such
constraint; only a `(user_id, created_at)`-friendly index.

---

## 9. RLS Policies

Enabled on **all 41 tables**. Policies rely exclusively on `auth.uid()`; a
client-supplied `user_id` is always re-checked server-side via `WITH CHECK`.

- **User-owned tables (generic, generated per table):**
  - `SELECT` → `using (user_id = auth.uid())`
  - `INSERT` → `with check (user_id = auth.uid())`
  - `UPDATE` → `using (user_id = auth.uid()) with check (user_id = auth.uid())`
  - `DELETE` → `using (user_id = auth.uid())`
- **`profiles`:** same four policies keyed on `id = auth.uid()`.
- **Hybrid `exercises` / `foods`:**
  - `SELECT` → `user_id = auth.uid() OR user_id IS NULL` (own + master rows)
  - `INSERT` → `user_id = auth.uid()` (can create custom only)
  - `UPDATE` / `DELETE` → `user_id = auth.uid()` (master rows immutable to app)
- **Master tables:** `SELECT to authenticated using (true)`; INSERT/UPDATE/DELETE
  policies are `to authenticated ... with check (false)` / `using (false)` so the
  app can never write. No anon policies → anon role has zero access. Only the
  privileged `service_role` (SQL/admin) can publish master data — never exposed to Flutter.
- **`sync_changes`:** `SELECT to authenticated using (user_id = auth.uid() OR user_id IS NULL)`.
  No write policies; rows are written exclusively by SECURITY DEFINER trigger
  functions (which bypass RLS).
- **`master_data_versions`:** `SELECT to authenticated using (true)`; no writes.

---

## 10. Master Data Strategy

- Global rows live in master tables and hybrid tables with `user_id IS NULL`.
- **Single source of truth:** the developer publishes catalogs directly in
  Supabase (SQL/psql/seeder RPC), then bumps the catalog version with
  `bump_master_data_version('food')` (etc.).
- **No per-user duplication:** catalogs are shared; user-owned custom rows are
  the only per-user entries.
- **Client read path:** `SELECT * FROM <master> WHERE updated_at > :last_synced_at`
  after detecting a `master_data_versions.data_version` change. Tombstones
  (`deleted_at`) appear in the same window because the metadata trigger bumps
  `updated_at` on soft deletes.
- **Identity:** master rows are keyed by stable UUID; the client maps them to the
  local SQFlite autoincrement `id` on first insert so existing
  `workout_exercise`/`food_favorite`/log references stay valid.
- **Rich media:** `image_url` / `gif_url` / `avatar_url` are Supabase Storage /
  CDN URLs (the existing `gif_path`/`image` columns will store these URLs).

---

## 11. User Data Strategy

- Every user table carries `user_id` (FK → `auth.users`) and is fully RLS-gated.
- **Write path:** local SQFlite first → `sync_event` queue → push via the future
  Supabase transport (upsert by client-generated UUID).
- **Read path:** incremental pull via `sync_changes` cursor + Realtime for live
  tables.
- **Singletons:** `profiles` (`id`), `user_settings` (`user_id` unique),
  `user_levels` (`user_id` unique) — upserted by natural key.
- **Device-local data stays local:** PIN hash, biometric/app-lock flags,
  encryption keys, screenshot lock, session timeouts and the local sync queue
  are NOT in the cloud schema.

---

## 12. Soft Delete Strategy

`deleted_at timestamptz` (nullable) is applied to:

- **All user-owned content tables** (29) → an offline device must learn about
  deletions performed elsewhere; tombstones make the incremental pull correct.
  The change log detects the soft-delete transition and records operation
  `'DELETE'` automatically.
- **All master tables** (10) → devices must learn that a food/exercise/category
  was retired without breaking existing references (FKs stay intact).

**No soft delete in practice (rationale):**
- `profiles`, `user_settings`, `user_levels` — account-scoped singletons whose
  lifecycle is tied to `auth.users(id)` cascade; deletion means account deletion.
  They still carry the standard `deleted_at` column so the generic change-log
  trigger stays uniform, but the column is unused in normal operation.
- `sync_changes` / `master_data_versions` — append-only / cursor tables.
- `calorie_log` — not in the cloud at all (derived).

Delete flow: clients issue an `UPDATE` setting `deleted_at = now()`
(recommended) OR a hard `DELETE`; both are captured by the change-log triggers.

---

## 13. Change-Log Strategy

**Table:** `sync_changes` — append-only, written by SECURITY DEFINER triggers.

| Column | Meaning |
|---|---|
| `id bigint identity` | **Monotonic server cursor** — the client remembers the max `id` it consumed |
| `table_name` | Which entity changed |
| `record_id` | The row's UUID |
| `operation` | `INSERT` \| `UPDATE` \| `DELETE` |
| `user_id` | Owner (null never logged; master rows use `master_data_versions`) |
| `payload` | Full JSONB row snapshot (client can apply without a second round-trip) |
| `created_at` | Server timestamp |

Triggers:
- `log_sync_change()` (AFTER INSERT/UPDATE) — logs INSERT/UPDATE, and detects
  soft-delete (`deleted_at` newly set) → logs `DELETE`. **Skips master rows**
  (`user_id IS NULL`) so bulk catalog uploads never flood the log.
- `log_sync_change_delete()` (AFTER DELETE) — logs physical deletes.
- `log_profile_change()` — dedicated function for `profiles` (owner column is `id`).

No recursive triggers (the log table has no triggers). No duplicate records in
normal operation; the client applies rows idempotently (upsert by `record_id`,
delete by `record_id`), so a replay after a missed cursor is safe.

**Cursor contract for the client:** `SELECT * FROM sync_changes WHERE user_id = :uid AND id > :last_cursor ORDER BY id`.

---

## 14. Sync Cursor / Version Strategy

| Scope | Cursor | Query |
|---|---|---|
| User data (initial) | `last_cursor = 0` | `sync_changes` for the user |
| User data (incremental) | stored `last_cursor` | `sync_changes WHERE user_id=:uid AND id>:last_cursor` |
| User data (recovery) | reset cursor to a safe point | re-pull + idempotent upsert (no duplicates thanks to UUID PKs) |
| Master catalogs | `master_data_versions.data_version` | compare version; then `WHERE updated_at > :last_pull` |
| Conflict detection | `row_version` + `updated_at` | server increments `row_version` on every change |

The client persists per-user `last_cursor` and per-catalog
`last_master_sync_at`/`data_version` locally (SQFlite). Initial sync = cursor 0 +
all master catalogs; incremental = continue cursors; recovery = reset + re-pull
(never a full-table re-download for user data, since the change log replays).

---

## 15. Conflict Preparation

The schema provides the raw material for conflict resolution (logic ships in a
later phase):

- **`updated_at`** — server clock authority (trigger-maintained; never trusted
  from the device clock).
- **`row_version`** — server-incremented revision on every UPDATE; the client
  sends its `base_version` with each push so the server can detect stale writes
  (optimistic concurrency).
- **`last_modified_by`** — which `auth.uid()` (or system, if null) last changed
  the row (diagnostic / "other device wrote this" visibility).
- **`deleted_at`** — tombstones make delete-vs-update races reconcilable
  (a newer edit resurrects a tombstoned row by upsert).
- Deterministic rules (later phase): LWW on `(row_version, updated_at)` with a
  UUID tie-break; user data preferred over catalog data; `manualMerge` escape
  hatch retained from the existing `SyncConflictStrategy` enum.

No resolution logic is implemented in the database in this phase.

---

## 16. Realtime Strategy

Enabled on the **`supabase_realtime` publication** for (filtered by RLS +
`user_id=eq.<uid>`):

`daily_progress`, `food_logs`, `water_logs`, `weight_logs`, `workouts`,
`workout_history`, `reminders`, `sleep_logs`, `step_logs`,
`body_measurements`, `bmi_logs`, `streaks`.

Rationale:
- These tables drive the dashboard and day-to-day logging where live
  cross-device updates add the most value.
- **Deliberately NOT realtime:** master catalogs (large, use version-based
  incremental pull — Realtime would broadcast thousands of rows on bulk upload)
  and high-volume append-only logs (`xp_history`, `exercise_history`,
  `reminder_history`) which rely on the cursor pull instead.
- Realtime is an accelerator only; the `sync_changes` cursor pull remains the
  correctness backstop and always runs on app start / connectivity restore.

---

## 17. Bulk Upload Strategy

- Developer loads master data with `INSERT ... ON CONFLICT (id) DO UPDATE`
  (idempotent upsert), then calls `bump_master_data_version('<catalog>')` to
  advance the version cursor.
- Clients detect the version bump, then pull **only changed rows**
  (`updated_at > last_pull`, including tombstones) in pages — never the whole table.
- Bulk inserts fire only the cheap `set_row_metadata()` trigger; master rows are
  **not** written to `sync_changes` (skipped by the log function), so a 1,000-row
  food upload creates zero change-log rows.
- Existing seed datasets (212 foods, 83 exercises, 26 workouts, 21+6 categories,
  4 goal templates, 7 achievements, 8 badges) are uploaded in
  `002_master_seed.sql`, which is **regenerated** from the app's own Dart seed
  data by `tool/generate_master_seed.dart` (`dart run tool/generate_master_seed.dart`).
  It is idempotent (ON CONFLICT DO NOTHING) and bumps the `master_data_versions`
  cursors for every populated catalog.

---

## 18. Security Considerations

- RLS on every table; `auth.uid()` only. `service_role` is never used from Flutter.
- No database passwords, JWT secrets, or service keys in the app or repository;
  the app uses the Supabase anon/publishable key via `--dart-define`.
- Master tables: authenticated read-only; writes reserved for privileged paths
  (explicit `with check (false)` / `using (false)` policies).
- `sync_changes` is append-only to the app; SECURITY DEFINER trigger functions
  carry `set search_path = public` to avoid search-path hijacking.
- Change-log payloads contain only the app's own data; error/device-local data
  stays in SQFlite.

---

## Appendix — Files

- `supabase/migrations/001_initial_nexfit_schema.sql` — deterministic, organized,
  production-oriented DDL (tables, indexes, triggers, RLS, realtime). **No seed data.**
- `docs/SUPABASE_DATABASE_SCHEMA.md` — this document.

## Appendix — Validation Checklist (manual review performed)

- [x] Foreign keys valid; no circular dependencies.
- [x] RLS enabled on all tables; ownership via `auth.uid()`; master data read-only.
- [x] Indexes cover sync cursors, FK lookups and master pull.
- [x] Unique constraints prevent duplicates without breaking history.
- [x] Timestamps server-generated (`now()` defaults + `set_row_metadata()` trigger).
- [x] No recursive triggers; master rows excluded from the change log.
- [x] Soft delete applied to syncable content; singletons excluded (documented).
- [x] Auth references correct (`auth.users(id)`).
- [x] Master data permissions: users read, never write.
