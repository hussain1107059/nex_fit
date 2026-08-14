# NexFit — Sync Table Matrix

> Phase 08 deliverable. Audited against the actual local schema
> (`lib/data/datasources/local/app_database.dart`), the actual DAO layer
> (`lib/data/datasources/local/*.dart`) and the deployed Supabase schema
> (`supabase/migrations/001_initial_nexfit_schema.sql`).
> Classification: `USER_SYNCABLE` / `MASTER_DATA` / `LOCAL_ONLY` / `SYNC_METADATA`.

## 1. Classification legend

| Class | Meaning | Sync direction |
|---|---|---|
| `USER_SYNCABLE` | Per-user rows, two-way sync between SQFlite and Supabase | push + pull |
| `MASTER_DATA` | Global catalog, single source of truth in Supabase, read-only for the app | pull only |
| `LOCAL_ONLY` | Device-local; never uploaded | none |
| `SYNC_METADATA` | Sync plumbing (change log, version cursors, outbox) | none (internal) |

## 2. User-owned tables (`USER_SYNCABLE`)

| Local table | Local PK | Cloud table | Cloud PK | Currently sync-tracked (DAO audit) | Push | Pull |
|---|---|---|---|---|---|---|
| `user_profile` | `user_id` (TEXT) | `profiles` | `id` (= auth.uid()) | **Yes** (upsert→update; delete NOT tracked) | yes | yes |
| `app_settings` | `id` (INT) | `user_settings` | `id` (uuid) | **Yes** (upsert→update; delete NOT tracked) | yes | yes |
| `fitness_goal` | `id` (INT) | `fitness_goals` | `id` (uuid) | No | yes | yes |
| `workout` | `id` (INT) | `workouts` | `id` (uuid) | No | yes | yes |
| `workout_exercise` | `id` (INT) | `workout_exercises` | `id` (uuid) | No | yes | yes |
| `workout_history` | `id` (INT) | `workout_history` | `id` (uuid) | **Yes** (C/U/D tracked) | yes | yes |
| `exercise_history` | `id` (INT) | `exercise_history` | `id` (uuid) | No | yes | yes |
| `meal` | `id` (INT) | `meals` | `id` (uuid) | No | yes | yes |
| `meal_item` | `id` (INT) | `meal_items` | `id` (uuid) | No | yes | yes |
| `food_log` | `id` (INT) | `food_logs` | `id` (uuid) | No | yes | yes |
| `food_item` (custom rows only) | `id` (INT) | `foods` (`is_custom=true`) | `id` (uuid) | No | yes | yes |
| `water_log` | `id` (INT) | `water_logs` | `id` (uuid) | No | yes | yes |
| `weight_log` | `id` (INT) | `weight_logs` | `id` (uuid) | **Yes** (C/U/D tracked) | yes | yes |
| `bmi_log` | `id` (INT) | `bmi_logs` | `id` (uuid) | No | yes | yes |
| `body_measurement` | `id` (INT) | `body_measurements` | `id` (uuid) | **Yes** (C/U/D tracked) | yes | yes |
| `calorie_log` | `id` (INT) | (none — derived, recomputed) | — | No | no | no (recompute) |
| `sleep_log` | `id` (INT) | `sleep_logs` | `id` (uuid) | No | yes | yes |
| `step_log` | `id` (INT) | `step_logs` | `id` (uuid) | No | yes | yes |
| `reminder` | `id` (INT) | `reminders` | `id` (uuid) | **Yes** (C/U/D tracked) | yes | yes |
| `reminder_history` | `id` (INT) | `reminder_history` | `id` (uuid) | No | yes | yes |
| `achievement` | `id` (INT) | `user_achievements` | `id` (uuid) | No | yes | yes |
| `badge` | `id` (INT) | `user_badges` | `id` (uuid) | No | yes | yes |
| `streak` | `id` (INT) | `streaks` | `id` (uuid) | No | yes | yes |
| `daily_progress` | `id` (INT) | `daily_progress` | `id` (uuid) | **Yes** (upsert→update; delete tracked) | yes | yes |
| `xp_history` | `id` (INT) | `xp_history` | `id` (uuid) | No | yes | yes |
| `user_level` | `id` (INT) | `user_levels` | `id` (uuid) | No | yes | yes |
| `challenge` | `id` (INT) | `user_challenges` | `id` (uuid) | No | yes | yes |
| `milestone` | `id` (INT) | `challenge_milestones` | `id` (uuid) | No | yes | yes |
| `reward` | `id` (INT) | `user_rewards` | `id` (uuid) | No | yes | yes |
| `exercise_favorite` | `id` (INT) | `exercise_favorites` | `id` (uuid) | No | yes | yes |
| `food_favorite` | `id` (INT) | `food_favorites` | `id` (uuid) | No | yes | yes |

Notes:
- `user_profile` is the only table whose local PK (`user_id`) is also the cloud PK (`profiles.id == auth.uid()`); all other user tables need a stable UUID added locally (see §6 blocker).
- `calorie_log` is derived/derivable from `food_log` + `exercise_history`; cloud schema intentionally has no `calorie_logs` table (migration 001 §3).
- Only **7 of 31** user tables currently enqueue sync events. The other 24 are invisible to the two-way engine today.

## 3. Master / reference tables (`MASTER_DATA`)

| Local table | Cloud table | Currently sync-tracked | Direction |
|---|---|---|---|
| `workout_category` | `workout_categories` | No (INSERT..IGNORE seed) | cloud → local |
| `meal_category` | `meal_categories` | No (INSERT..IGNORE seed) | cloud → local |
| `exercise` (master rows, `user_id IS NULL`) | `exercises` (`user_id IS NULL`) | No | cloud → local |
| `food_item` (master rows, `user_id IS NULL`) | `foods` (`user_id IS NULL`) | No | cloud → local |
| (seeded workouts) | `workout_templates` + `workout_template_exercises` | No | cloud → local |
| (goal templates) | `goal_templates` | No | cloud → local |
| (achievements) | `achievement_defs` | No | cloud → local |
| (badges) | `badge_defs` | No | cloud → local |
| (challenges) | `challenge_defs` | No | cloud → local |

Master catalogs are pulled via `master_data_versions.data_version` cursors and are
never uploaded by the app. Version cursors are read from Supabase, never written by clients.

## 4. Local-only tables (`LOCAL_ONLY`)

| Table | Reason |
|---|---|
| `users` | Auth identity — replaced by Supabase `auth.users`; kept for local FK integrity |
| `backup_history` | Device-local backup log |
| `sync_event` | The offline outbox itself |
| `error_logs` | Device-local diagnostics |
| `sessions` | Device-local secure session records |
| `schema_migrations` | Internal |

## 5. Sync metadata (`SYNC_METADATA`)

| Table | Location | Purpose |
|---|---|---|
| `sync_changes` | Supabase only | Append-only change log; `id` = bigint cursor |
| `master_data_versions` | Supabase only | Per-catalog version cursors |
| `sync_state` | **does not exist yet** | Local per-user cursor / high-water marks (required — see §6) |

## 6. Blocking finding — local schema must change (NOT performed)

The local SQFlite schema **cannot support two-way sync as-is**, and the migration is
**strictly required** to build the sync foundation. Per phase instructions this is
being reported, not invented:

| Requirement | Reason |
|---|---|
| Add a stable `uuid TEXT NOT NULL UNIQUE` column to every `USER_SYNCABLE` table (all except `user_profile`, which already keys on `user_id`) | Cloud rows are keyed by client-generated UUID v4; local rows are `INTEGER AUTOINCREMENT`. Without a local UUID there is no way to match a pushed row to the server row (idempotent upsert) or to apply a pulled row without duplication. |
| Add `updated_at INTEGER` and `row_version INTEGER DEFAULT 0` to every `USER_SYNCABLE` table that lacks them | Conflict detection requires comparing local vs server revision. Cloud schema maintains `updated_at`/`row_version` via trigger; local must carry comparable values. |
| Add `deleted_at INTEGER` (soft-delete tombstone) to every `USER_SYNCABLE` table | The pull pipeline must apply remote deletions without physically losing locally-queued data; cloud sync model is tombstone-based. |
| New local `sync_state` table: `user_id`, `entity`, `last_cursor`, `last_synced_at` | Pull needs a persistent per-user, per-entity cursor that survives restarts. There is no local store for it today (`app_settings.last_sync_at` is a single global timestamp, not per-entity). |
| Add to `sync_event`: `event_uuid TEXT`, `device_id TEXT`, `base_version INTEGER` | The event contract requires an idempotency key, a device origin and the base revision for conflict resolution (cloud upserts must be safe to retry). |
| Extend `SyncStatus` states (code-only, no SQL): `processing`, `failed_retryable`, `failed_permanent` | Outbox state machine requires more than the current `pending`/`completed`/`failed`. |

These changes belong in a new **SQFlite migration v15** (`AppDatabase`). No migration
was written; the exact DDL is a follow-up decision pending the user's approval.
