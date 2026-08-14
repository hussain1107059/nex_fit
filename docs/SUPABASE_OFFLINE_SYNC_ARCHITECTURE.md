# NexFit — Supabase Migration & Offline-First Sync Architecture

> **Phase 01 — Analysis Only.** This document audits the existing NexFit codebase and
> proposes a target architecture for migrating to Supabase with two-way offline-first
> sync. **No application code was changed.** SQFlite stays the local source of truth.
> Firebase is NOT removed yet.

- **Repo root:** `D:\BadhonByte\nexfit`
- **Stack:** Flutter (Dart SDK `^3.12.2`), Riverpod (`flutter_riverpod ^2.6.1`), GoRouter (`^17.3.0`), SQFlite (`^2.4.3`), Firebase Auth, Google Drive backup.
- **Files:** 464 Dart files under `lib/` organized as Clean Architecture (`core / data / domain / injection / presentation / l10n`).
- **Target Supabase project:** `https://jzbkhtposhxlbgiyrbqg.supabase.co` (publishable/anon key available; **no secrets in source**).

---

## 1. Existing Architecture Audit

### 1.1 Layer layout

```
lib/
├── core/          constants, errors, extensions, network, security, theme, utils, widgets
├── data/
│   ├── datasources/local/      34 SQFlite DAO classes + AppDatabase + seed constants
│   ├── models/                 ~50 table<->entity mappers (XxxModel.toMap / fromMap)
│   ├── repositories/           50 repository implementations
│   └── services/               auth, backup, notifications, report, security, storage, sync
├── domain/
│   ├── entities/               ~75 domain entities (incl. progress/)
│   ├── repositories/           ~45 abstract repository interfaces
│   ├── services/               (domain service contracts)
│   └── usecases/               auth usecases (8) + others
├── injection/dependency_injection.dart   Composition root (all Riverpod providers)
├── presentation/
│   ├── providers/              Auth/Sync/Connectivity + feature providers
│   ├── router/app_router.dart  GoRouter (50+ routes)
│   └── screens/                auth, dashboard, exercise, gamification, nutrition,
│                               profile, progress, reminder, settings, shell, splash,
│                               water, weight, workout
└── l10n/                        generated localization (Bangla-first, bn/en)
```

### 1.2 Key facts confirmed by inspection

| Concern | Current implementation |
|---|---|
| State management | Riverpod (Notifier/NotifierProvider, StreamProvider, Provider) |
| Navigation | GoRouter; `/shell` hosts a 5-tab `IndexedStack` (Home, Workout, Progress, Nutrition, Profile) |
| Local DB | SQFlite via `AppDatabase` (14 versioned migrations, schema version `14`, file `nexfit.db`) |
| Auth | Firebase Auth (`firebase_core`, `firebase_auth`) + offline local-account fallback |
| Offline sync | Durable `sync_event` queue (migration v13) + `SyncEngine` with pluggable `SyncTransport` (currently no real transport) |
| Connectivity | `connectivity_plus` wrapped by `NetworkInfo` (OS-level only, no reachability probe) |
| Backup | Full encrypted DB snapshot (`NXFBK001`) → AES-256-GCM → Google Drive AppData |
| Encryption | AES-256-GCM field encryption (`nf1:` prefix) + versioned keys in keychain; `flutter_secure_storage` |
| Localization | `intl` gen-l10n, `main_locale: bn` |
| Multi-platform | Android/iOS/Web/Windows/macOS/Linux scaffolding present |

### 1.3 The existing sync seam (important)

`lib/data/services/sync/sync_engine.dart` already declares:

```dart
abstract interface class SyncTransport {
  Future<SyncEvent> push(SyncEvent event); // returns remote (possibly conflicting) event
}
```

and a `ConflictResolver` (`latestWins` / `manualMerge`) plus a `SyncEventRecorder`
static facade used by 7 of 34 DAOs. This is a deliberate extension point: **the
Supabase transport plugs in here without changing the queue contract.** However:

- Only 7 DAOs record sync events today (`user_profile`, `app_settings`,
  `weight_log`, `body_measurement`, `daily_progress`, `reminder`, `workout_history`).
  The core fitness domains (workouts, food logs, water, exercise, sleep, steps,
  gamification) do **not** enqueue events yet.
- `SyncEngine.processQueue` without a transport simply acknowledges events locally
  (offline-first); the dashboard "sync" card drives it via `SyncController`.

---

## 2. Existing SQFlite Tables

Database `nexfit.db`, version `14` (`lib/core/constants/app_constants.dart`). All
timestamps stored as **epoch milliseconds INTEGER** via `ModelCodec`.

| # | Table | Created in | Ownership | Sync-worthy |
|---|---|---|---|---|
| 1 | `schema_migrations` | v1 (internal) | internal | No |
| 2 | `users` | v1 | account | replaced by Supabase `auth.users` |
| 3 | `user_profile` | v2 (+v3) | user | **Yes** (singleton per user) |
| 4 | `fitness_goal` | v2 | user + templates | **Yes** |
| 5 | `workout_category` | v2 (+v4) | **master** (global, seeded) | Yes (master) |
| 6 | `workout` | v2 (+v4) | user (`is_custom` 0/1) | **Yes** |
| 7 | `exercise` | v2 (+v4,+v5) | **master** + user custom | Yes (master + user) |
| 8 | `workout_exercise` | v2 | user (part of workout) | **Yes** |
| 9 | `workout_history` | v2 (+v14 idx) | user | **Yes** |
| 10 | `exercise_history` | v2 (+v14 idx) | user | **Yes** |
| 11 | `meal_category` | v2 (+v6) | **master** (global) | Yes (master) |
| 12 | `meal` | v2 | user | **Yes** |
| 13 | `food_item` | v2 (+v6) | **master** + user custom | Yes (master + user) |
| 14 | `food_log` | v2 (+v6,+v14) | user | **Yes** |
| 15 | `water_log` | v2 (+v7,+v14) | user | **Yes** |
| 16 | `weight_log` | v2 (+v14) | user | **Yes** |
| 17 | `bmi_log` | v2 (+v14) | user | **Yes** |
| 18 | `body_measurement` | v2 (+v8,+v14) | user | **Yes** |
| 19 | `calorie_log` | v2 (+v14) | user | **Yes** (derived; optional) |
| 20 | `sleep_log` | v2 (+v14) | user | **Yes** |
| 21 | `step_log` | v2 (+v14) | user | **Yes** |
| 22 | `reminder` | v2 (+v9,+v14) | user | **Yes** |
| 23 | `achievement` | v2 (+v10) | user (unlock state) | **Yes** |
| 24 | `badge` | v2 (+v10) | user (progress state) | **Yes** |
| 25 | `streak` | v2 | user | **Yes** |
| 26 | `daily_progress` | v2 (+v14) | user | **Yes** |
| 27 | `app_settings` | v2 (+v11,+v12,+v13) | user (singleton) | **Yes** |
| 28 | `backup_history` | v2 (+v12) | user | No (local log) |
| 29 | `exercise_favorite` | v5 | user (join) | **Yes** |
| 30 | `food_favorite` | v6 | user (join) | **Yes** |
| 31 | `meal_item` | v6 | user (part of meal) | **Yes** |
| 32 | `reminder_history` | v9 (+v14) | user | **Yes** |
| 33 | `xp_history` | v10 (+v14) | user | **Yes** |
| 34 | `user_level` | v10 | user | **Yes** |
| 35 | `challenge` | v10 | user (progress state) | **Yes** |
| 36 | `milestone` | v10 | user (part of challenge) | **Yes** |
| 37 | `reward` | v10 | user (claim state) | **Yes** |
| 38 | `sync_event` | v13 | local queue | No (queue itself) |
| 39 | `error_logs` | v13 | local log | No |
| 40 | `sessions` | v13 | local security | No |

**Seed/master content already in SQLite:** 21 `workout_category`, 6 `meal_category`,
4 `fitness_goal` templates (migrations), 83 exercises (`workout_seed_data.dart`),
26 workouts / 148 links (`kSeedWorkouts`), 212 foods (`food_seed_data.dart`).

---

## 3. Existing Models

~50 `*Model` classes in `lib/data/models/` map SQLite rows to domain entities. All
follow `toMap` / `fromMap` with `ModelCodec` epoch-ms conversion. Key models:

- `app_user_model.dart` — maps **Firebase** `fb.User` → `AppUser` (`id=uid`,
  email, displayName, photoUrl, isEmailVerified, provider). This is the single
  auth-mapping seam that will become Supabase.
- `exercise_model.dart` — includes `gif_path`, `instructions`, `tips`,
  `common_mistakes`, `safety_instructions` (newline-encoded lists), `is_custom`.
- `food_item_model.dart` — full micronutrient set, `barcode`, `image_path`, `is_custom`.
- `workout_model.dart`, `workout_category_model.dart`, `meal_category_model.dart` — catalog rows.
- `sync_event_model.dart` — maps `SyncEvent` to the `sync_event` table.
- Domain entities mirror these in `lib/domain/entities/`.

> Note: local autoincrement `id`s are the primary keys everywhere. Two-way sync
> requires a **global stable UUID** added to every syncable table (see §10, §16).

---

## 4. Existing Repositories

`lib/domain/repositories/` declares interfaces; `lib/data/repositories/` implements
them (pure pass-through to local data sources today).

Notable aggregator repositories:
- `auth_repository.dart` / `auth_repository_impl.dart` — auth + offline fallback.
- `backup_repository.dart` — transport-agnostic (`uploadBytes` / `listBackups` /
  `downloadBytes` / `deleteBackup`) → currently backed by `GoogleDriveBackupService`.
- `sync_event_repository.dart` — 9-method queue contract used by `SyncEngine`.
- `dashboard_repository_impl.dart`, `nutrition_repository_impl.dart`,
  `workout_library_repository_impl.dart`, `workout_session_repository_impl.dart`,
  `progress_analytics_repository_impl.dart` — feature-level aggregations.
- `user_fitness_profile_repository_impl.dart` — profile + targets.

Repository pattern is clean and single-purpose; the remote (Supabase) data source
can be added **behind the same interfaces** without touching consumers.

---

## 5. Existing Authentication Flow

```
SplashScreen._bootstrap()
  ├─ FirebaseService.initialize()          (optional; null options → offline mode)
  ├─ googleSignInService.initialize()
  ├─ appDatabase.database
  ├─ authController.syncSession()          (re-subscribe + getCurrentUser)
  ├─ AppErrorLogger.installGlobalHandlers(); FieldEncryption.configure();
  │    SyncEventRecorder.configure(...)     (line ~96)
  ├─ SessionManager.validate(user.id)       (expiry + device-change → logout)
  └─ context.go(login)                      (router redirects appropriately)

AuthController (Notifier<AuthState>)
  ├─ watches authRepository.authStateChanges (stream)
  ├─ signInWithEmail / signUpWithEmail / signInWithGoogle
  ├─ sendVerificationEmail / refreshVerificationStatus / resetPassword
  └─ signOut / deleteAccount

AuthRepositoryImpl
  ├─ online:  AuthService (FirebaseAuth) → AppUserModel.fromFirebase → persist profile
  └─ offline: local accounts in secure storage (StorageKeys.offlineUsers),
              dev account test@gmail.com/123456, in-memory stream

Router redirect (_resolveRedirect):
  not signed in          → public routes only, else /login
  signed in, unverified  → /email-verification only
  signed in, verified    → public routes → /shell
```

Use cases (8) in `lib/domain/usecases/auth/`; screens in
`lib/presentation/screens/auth/` (`login`, `register`, `forgot_password`,
`email_verification`). Google buttons exist on **login** and **register** screens.

### Required for Supabase (email/password only)

- Replace `AuthService` with a `SupabaseAuthService` (or a new `SupabaseAuthRepository`)
  that keeps the same `AuthRepository` contract and the same `AuthException`
  localization-key mapping (`authEmailInUse`, `authWrongPassword`, `authUserNotFound`, …).
- Map Supabase `User.email_confirmed_at` → `AppUser.isEmailVerified`; keep the
  `/email-verification` gate.
- **Do not implement Google login.** Remove the Google buttons/blocks from
  `login_screen.dart` and `register_screen.dart` and their underlying chain
  (`AuthController.signInWithGoogle`, `SignInWithGoogleUsecase`,
  `AuthRepository.signInWithGoogle`, `AuthService.signInWithGoogle`).
- ⚠️ `GoogleSignInService` is **still required** for Google Drive backup — keep it
  and its initialization, only detach it from auth.

---

## 6. Existing Firebase Dependencies

| Dependency | Where | Role |
|---|---|---|
| `firebase_core ^4.12.1` | `firebase_service.dart`, `firebase_options.dart` | init / config |
| `firebase_auth ^6.5.6` | `auth_service.dart`, `auth_repository_impl.dart`, `app_user_model.dart` | email + Google auth |
| `google_sign_in ^7.2.0` | `auth_service.dart`, `google_sign_in_service.dart`, Drive backup | Google auth **and** Drive backup transport |

`lib/firebase_options.dart` reads build-time `--dart-define`
(`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`,
`FIREBASE_PROJECT_ID`, optional `FIREBASE_STORAGE_BUCKET`). When absent →
`FirebaseService.isReady == false` → full offline-first mode.

**Keep Firebase in place for now** (per instructions). It will be retired after
Supabase auth + sync are proven. The anon key / project URL must be provided via
the same `--dart-define` mechanism (never committed).

---

## 7. Existing Backup Dependencies

| Dependency | Role |
|---|---|
| `googleapis`, `googleapis_auth` | Drive v3 API (AppData folder) |
| `pointycastle`, `crypto` | AES-256-GCM + SHA-256 |
| `archive`, `zlib` | compression |
| `connectivity_plus`, `battery_plus`, `device_info_plus` | backup gating |
| `flutter_secure_storage` | backup key + field-encryption keys (keychain only) |
| `share_plus`, `pdf`, `csv` | export/share |

Flow: `SettingsStorageService.createSnapshotBytes()` (`VACUUM INTO`) → SHA-256 →
zlib → AES-256-GCM → `NXFBK001` container → `GoogleDriveBackupService.uploadBytes`
(AppData). Restore: header parse → decrypt → verify → atomic DB file replace.

**Migration notes:** `BackupRepository` is transport-agnostic, so a Supabase
Storage-backed repository could replace Drive later. The device-keychain-only
encryption key is a cross-device hazard under a cloud-first model (see §20).

---

## 8. Existing UI / Features That MUST NOT Be Changed

Preserve all of the following (custom fixes, animations, GIFs, styling, themes):

- **Themes:** light Material 3 + optional dynamic color (`AppTheme.light`,
  `DynamicColorBuilder`). No dark mode. Do not change.
- **Animations:** splash animations (`splash_screen.dart`), `shimmer`, goal rings,
  animated cards, `AnimatedSwitcher` in auth screens, `TickerMode`-gated tab
  animations, exercise player animations. Do not remove.
- **Exercise GIFs / cover art:** `exercise_cover.dart`, `exercise_card.dart`,
  `workout_cover.dart`; `gif_path` column exists and is the future home of remote GIF URLs.
- **All 50+ screens & widgets** under `lib/presentation/` — no redesigns.
- **Navigation:** GoRouter route table, 5-tab `AppShellScreen`, deep links.
- **Localization:** `l10n.yaml`, `main_locale: bn`, all `AppLocalizations` keys.
- **Offline-first auth UX:** splash bootstrap, remember-me, session restore,
  app-lock (`LockScreen`), PIN/biometric flows.
- **Backup/restore UI, storage settings, security settings, developer settings.**
- **Dashboard** widgets (health card, sync card, gamification overview, weekly stats…).
- **Domain/repository contracts** — extend, don't replace.

---

## 9. Supabase Target Architecture

```
┌────────────────────────────────────────────────────────────┐
│  UI (presentation/)  — unchanged                           │
│   Riverpod providers → usecases → domain repositories      │
└───────────────┬────────────────────────────────────────────┘
                │ (interfaces unchanged)
┌───────────────▼────────────────────────────────────────────┐
│  Data layer (data/)                                        │
│   repository impls          (existing, add remote source)  │
│   ├─ local source: SQFlite DAOs  (source of truth for UI)  │
│   └─ remote source: SupabaseDataSource (new, per entity)   │
│   SyncEventRecorder.record(...)  → sync_event queue        │
└───────┬──────────────────────────┬─────────────────────────┘
        │                          │
┌───────▼──────────┐      ┌────────▼─────────────────────────┐
│ SyncEngine        │      │ ConnectivityService (enhanced)  │
│  push → transport │      │  OS connectivity + reachability │
│  pull ← changelog │      └────────┬────────────────────────┘
└───────┬──────────┘               │
        │                          │
┌───────▼──────────────────────────▼─────────────────────────┐
│ SupabaseClient (supabase_flutter)                          │
│  Auth (email/password)  |  Postgres (RPC + tables)  |      │
│  Realtime (postgres_changes)  |  Storage (backup/photos)   │
└────────────────────────────────────────────────────────────┘
```

### New packages (to add in the implementation phase)

- `supabase_flutter` — core client, auth, DB, realtime, storage.
- (Optional) `internet_connection_checker` (or a small HTTP HEAD probe) for real
  internet reachability beyond `connectivity_plus`.

### Configuration (no secrets in source)

- Provide `SUPABASE_URL`, `SUPABASE_ANON_KEY` via `--dart-define` (same pattern as
  `firebase_options.dart`), or via `--dart-define-from-file`. Add them to `.gitignore`
  if using a local env file. Never commit `service_role` / JWT / DB password.

---

## 10. Supabase Database Schema Proposal

### 10.1 Cross-cutting conventions

- **UUID primary keys** for all syncable rows (client-generated, `uuid v4`), so
  Device A/B and server can insert the same logical row idempotently.
- Every syncable table carries sync metadata:
  - `created_at timestamptz not null default now()`
  - `updated_at timestamptz not null default now()`
  - `deleted_at timestamptz` (soft-delete tombstone; keeps the incremental sync
    changelog correct across devices).
- Every user table carries `user_id uuid not null references auth.users(id) on delete cascade`.
- `row_version bigint not null default 0` — optimistic concurrency counter
  (server increments on each upsert via trigger).
- Indexes on `(user_id, updated_at)` and `(deleted_at)` for incremental pulls.
- A `trigger` keeps `updated_at`/`row_version` fresh on every write.

### 10.2 Auth & profile

```sql
-- Auth: Supabase auth.users (managed by Supabase Auth). Email+password only.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  email text,
  photo_url text,               -- Storage object URL (see §20 photo note)
  height_cm double precision,
  weight_kg double precision,
  gender text,
  birth_date timestamptz,
  activity_level text,
  target_calories double precision,
  target_protein double precision,
  target_carbs double precision,
  target_fat double precision,
  target_water_ml integer,
  target_steps integer,
  target_weight_kg double precision,
  fitness_goal text,
  country text,
  language text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### 10.3 User-owned tables (one per SQLite syncable table)

Mapping (SQLite → Supabase):

| SQLite | Supabase | Notes |
|---|---|---|
| `user_profile` | `profiles` (above) | singleton |
| `app_settings` | `user_settings` | singleton |
| `fitness_goal` | `fitness_goals` | |
| `workout` | `workouts` | |
| `workout_exercise` | `workout_exercises` | |
| `workout_history` | `workout_history` | |
| `exercise_history` | `exercise_history` | |
| `meal` | `meals` | |
| `meal_item` | `meal_items` | |
| `food_log` | `food_logs` | |
| `food_item` (custom only) | `custom_foods` (or `foods` with `is_custom`) | see master |
| `water_log` | `water_logs` | |
| `weight_log` | `weight_logs` | |
| `bmi_log` | `bmi_logs` | |
| `body_measurement` | `body_measurements` | |
| `calorie_log` | `calorie_logs` | derived; sync if kept |
| `sleep_log` | `sleep_logs` | |
| `step_log` | `step_logs` | |
| `reminder` | `reminders` | |
| `reminder_history` | `reminder_history` | |
| `exercise_favorite` | `exercise_favorites` (user_id, exercise_id uuid) | |
| `food_favorite` | `food_favorites` (user_id, food_id uuid) | |
| `achievement` | `user_achievements` | unlock state |
| `badge` | `user_badges` | progress state |
| `streak` | `streaks` | |
| `daily_progress` | `daily_progress` | |
| `xp_history` | `xp_history` | |
| `user_level` | `user_levels` | singleton |
| `challenge` | `user_challenges` | progress state |
| `milestone` | `challenge_milestones` | |
| `reward` | `user_rewards` | claim state |

Local-only (never uploaded): `sync_event`, `error_logs`, `sessions`,
`backup_history`, `schema_migrations`.

### 10.4 Master / reference tables (global, no `user_id`)

```sql
create table public.exercises (
  id uuid primary key,          -- stable, references the seed catalog
  name text not null,
  scientific_name text,
  description text,
  instructions text,
  body_part text,
  secondary_muscle text,
  equipment text,
  difficulty text,
  category text,
  image_url text,               -- replaces image/gif_path
  gif_url text,                 -- animated exercise GIFs
  calories_per_minute double precision,
  estimated_calories double precision,
  duration_seconds int default 30,
  sets int default 3,
  reps int default 12,
  rest_seconds int default 30,
  tips text, common_mistakes text, safety_instructions text,
  created_at timestamptz, updated_at timestamptz, deleted_at timestamptz,
  row_version bigint default 0
);

create table public.foods (
  id uuid primary key,
  name text not null, brand text, category text,
  serving_size text, serving_grams double precision,
  calories double precision, protein double precision, carbs double precision,
  fat double precision, fiber double precision, sugar double precision,
  sodium double precision, potassium double precision, calcium double precision,
  iron double precision, vitamin_a double precision, vitamin_c double precision,
  water_percentage double precision, barcode text, image_url text,
  created_at timestamptz, updated_at timestamptz, deleted_at timestamptz,
  row_version bigint default 0
);

create table public.workout_templates ( ... );   -- the 26 seeded routines, exercises jsonb
create table public.workout_categories ( ... );  -- 21 categories (slug unique)
create table public.meal_categories ( ... );     -- 6 meal slots (slug unique)
create table public.achievement_defs ( ... );    -- definitions; user unlocks in user_achievements
create table public.badge_defs ( ... );          -- definitions; user progress in user_badges
create table public.challenge_defs ( ... );      -- definitions; user progress in user_challenges
create table public.goal_templates ( ... );      -- 4 fitness goal templates
create table public.master_data_versions (
  catalog text primary key,      -- 'exercise' | 'food' | 'workout_template' | ...
  schema_version bigint not null,
  data_version bigint not null,  -- bumped on every bulk publish
  updated_at timestamptz not null default now()
);
```

Master tables are keyed by a stable `slug`/natural key in the local DB and by a
deterministic UUID in Supabase, so idempotent upserts keep local `id` links valid
(`workout_exercise`, `food_favorite`, log references).

---

## 11. User-Owned vs Master/Reference Data Classification

| Category | Tables | Strategy |
|---|---|---|
| **User-owned (per-user, two-way sync)** | profiles/settings, fitness_goals, workouts, workout_exercises, workout_history, exercise_history, meals, meal_items, food_logs, water_logs, weight_logs, bmi_logs, body_measurements, calorie_logs, sleep_logs, step_logs, reminders, reminder_history, exercise_favorites, food_favorites, user_achievements, user_badges, streaks, daily_progress, xp_history, user_levels, user_challenges, challenge_milestones, user_rewards | UUID PK, `user_id = auth.uid()`, RLS enforced, incremental pull by `updated_at`, push via sync queue |
| **Master/reference (global, single source of truth)** | exercises, foods, workout_templates, workout_categories, meal_categories, achievement_defs, badge_defs, challenge_defs, goal_templates | Published by the developer via SQL/seed; client **pulls** incrementally by `master_data_versions`; never per-user duplicated; read-only for clients (RLS `using (true)` for authenticated) |
| **Local-only (never synced)** | sync_event (queue), error_logs, sessions, backup_history, schema_migrations | Stay in SQFlite only |

> Current SQLite model overlaps the two: `exercise` / `food_item` mix global
> (`user_id IS NULL`) and custom (`is_custom = 1`) rows; `workout` stores the 26
> seeded templates as per-user `is_custom = 0` copies. The target splits these:
> master catalogs live in Supabase global tables; only genuinely custom rows are
> user-owned.

---

## 12. Two-Way Sync Architecture

### 12.1 Device → Server (push)

1. Repository/data-source writes → **SQFlite first** (immediate).
2. `SyncEventRecorder.record(entity, entityId, operation, payload, userId)` →
   `sync_event` row (`pending`), duplicate-coalesced by `SyncEngine.track`.
3. `SyncEngine.processQueue(userId, transport: SupabaseSyncTransport)`:
   - fetch `pending` in pages of 500 (oldest first),
   - `transport.push(event)` → maps entity/operation to a Supabase table upsert
     (`create`/`update` → `upsert`, `delete` → soft-delete `deleted_at=now()` or hard delete),
   - on success → `completed` + `synced_at`; on failure → retry with
     `retry_count`, give up after `syncEventMaxRetries` (3) → `failed` (visible in UI).
4. The UI never waits for the server — it renders from SQFlite immediately.

### 12.2 Server → Device (pull)

1. After the push drain (and periodically / on app start / on connectivity restore),
   run **incremental pull** per entity:
   `select * from <table> where user_id = :uid and updated_at > :last_synced_at`
   (plus tombstones `deleted_at is not null`).
2. Insert/update SQFlite with conflict resolution (§16); apply soft-deletes locally.
3. Notify Riverpod providers → UI updates automatically (existing streams/providers).
4. **Realtime** (§17) applies live changes for immediate cross-device updates.

### 12.3 Who calls what

- New `SupabaseSyncTransport implements SyncTransport` (push side).
- New `SyncPuller` / `IncrementalSyncService` (pull side) orchestrated by a
  `SyncOrchestrator` (replaces the transport-less `SyncController.runSync`).
- Triggered by: app start, login, connectivity restore, periodic timer, manual
  "Sync now", and Realtime events.

---

## 13. Sync Queue Design

Existing `sync_event` table already matches the required shape almost exactly:

```sql
sync_event(
  id INTEGER PRIMARY KEY AUTOINCREMENT,   -- local
  user_id TEXT NOT NULL,
  entity TEXT NOT NULL,          -- table name
  entity_id TEXT NOT NULL,       -- row id (→ will become row UUID)
  operation TEXT NOT NULL,       -- create | update | delete
  payload TEXT,                  -- JSON snapshot for the upsert
  status TEXT DEFAULT 'pending', -- pending | completed | failed
  retry_count INTEGER DEFAULT 0,
  conflict_strategy TEXT DEFAULT 'latest_wins',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  synced_at INTEGER,
  last_error TEXT
)
```

**Proposed additions (SQLite migration v15):**

| Column | Purpose |
|---|---|
| `event_uuid TEXT` | global unique operation id (idempotent server apply) |
| `batch_id TEXT` | groups a device→server push run |
| `device_id TEXT` | which device created the op |
| `base_version INTEGER` | `row_version` the payload was derived from (conflict detection) |
| `expires_at INTEGER` | optional hard-expiry for stale ops |

Semantics:
- `create`/`update` use **`upsert on conflict (id) do update`** keyed by the row UUID.
- `delete` is a **soft delete** (`deleted_at = now()`) so other devices receive the tombstone via incremental pull; hard delete is a later cleanup job.
- Duplicate coalescing: `SyncEngine.track` already merges consecutive same-entity ops.
- Retention: completed events pruned after 14 days (`syncEventRetention`).

---

## 14. Initial Sync Design

Triggered on first login on a device (fresh install, cleared data, or
`isFirstSync == true`):

1. **Authenticate** with Supabase (email/password).
2. **Initialize local DB** (migrations already ran; `AppDatabase`).
3. **Detect existing local data**: if the user already has rows (restored DB / re-login)
   → skip full download and go straight to incremental sync.
4. **Pull master/reference data** (if absent or stale): compare
   `master_data_versions` with local version; download changed catalogs in pages.
5. **Pull user-owned data**: for each user table, fetch all rows for `user_id`
   (only on true first sync), ordered and **batched** (e.g. 200–500/batch) into SQFlite
   inside transactions.
6. **Progress UI**: a non-blocking sync indicator (reuse the existing sync-card /
   banner patterns; do not redesign). Show step text + percentage.
7. **Resumable**: persist `last_synced_at` per entity as rows land, so an interrupted
   initial sync resumes rather than restarts; the pull is idempotent (upsert).
8. On completion: mark `isFirstSync = false`, enable Realtime subscriptions.

---

## 15. Incremental Sync Design

- Store per-entity high-water marks: `last_synced_at` in a small `sync_state`
  local table (or reuse `app_settings.last_sync_at` plus a per-entity map).
- **Pull window:** `updated_at > last_synced_at` for user tables; `deleted_at is not null`
  for tombstones; master catalogs via `master_data_versions.data_version`.
- Order of pull: newest-first or oldest-first? Use **oldest-first with a bounded
  page size** so a large backlog streams in without memory spikes; apply upserts.
- Conflict-safe apply: before writing a pulled row, compare `row_version`/`updated_at`
  against the local row (§16). Never blindly overwrite a newer local change that is
  still queued for push.
- **Idempotency:** UUID PKs + upserts guarantee no duplicate records when a pull and a
  push overlap.

---

## 16. Conflict Resolution Strategy

Goal: **never silently lose user data.**

1. **Version comparison:** every row carries `updated_at` (server timestamptz) and
   `row_version` (server-incremented bigint). The server is the clock authority for
   `updated_at`.
2. **Deterministic LWW (default):** the revision with the greater
   `(row_version, updated_at)` wins; if equal, a deterministic tie-break on the
   row UUID string. This is the existing `ConflictDecision.latestWins` policy.
3. **Prefer user-generated data:** because local writes are enqueued with a
   `base_version`, a local update that is newer than the server revision wins the push;
   a pull that would overwrite a local `pending` op is deferred until that op is pushed
   (prevents clobbering queued work).
4. **Retry:** push failures keep the op `pending` with `retry_count`; a capped
   exponential backoff on reconnect; `failed` after `syncEventMaxRetries` with the
   error surfaced in the sync UI (existing `last_error`).
5. **Duplicate prevention:** UUID PKs + `upsert on conflict` on both directions;
   `SyncEventRecorder` coalesces duplicate queue ops.
6. **Manual merge (escape hatch):** the existing `ConflictDecision.manual` /
   `SyncConflictStrategy.manualMerge` flags the op for a user decision; expose a
   lightweight conflict list UI in Settings (do not redesign the main screens).
7. **Soft deletes:** a delete is a tombstone; if a device edits a tombstoned row, the
   row is resurrected (upsert) and the delete's version is superseded.

---

## 17. Realtime Strategy

- Use **Supabase Realtime `postgres_changes`** channels per user:
  `channel('user-data:<uid>').onPostgresChanges(Insert|Update|Delete, table, filter: user_id=eq.<uid>)`.
- Realtime respects **RLS**, so a user can only ever receive their own rows.
- On each event: apply to SQFlite via the same conflict-safe apply path (§16), then
  refresh the affected Riverpod providers (existing provider structure).
- Realtime is a **nice-to-have accelerator** — the incremental pull (§15) remains the
  correctness backstop and is always run on reconnect/app-start.
- Master catalogs: realtime `Insert|Update` on master tables for authenticated
  users is optional; prefer periodic `master_data_versions` checks to avoid
  broadcasting large payloads.

---

## 18. Bulk Data Synchronization Strategy

Developer uploads large master catalogs (exercises, foods, templates, categories,
achievements, badges).

1. **Publish mechanism:** developer inserts/updates rows and bumps
   `master_data_versions.data_version` (and optionally `schema_version` when columns change).
2. **Client check:** pull `master_data_versions`; if `data_version` matches local, do
   nothing. **Never download the whole database.**
3. **Chunked download:** `RPC get_master_changes(catalog, since_version)` returns
   changed rows in pages (JSON, e.g. 500/page); client upserts each page in a
   transaction.
4. **Preserve local identity:** master rows are upserted by stable UUID, mapped to
   the local autoincrement id on first insert; existing links
   (`workout_exercise`, `food_favorite`, `food_log.food_item_id`) remain valid.
5. **Idempotent re-runs** mirror the current `INSERT OR IGNORE` / name-based upsert
   behaviour of `FoodSeeder` / `WorkoutSeeder`.
6. **Rich media (GIFs/images):** `gif_url`/`image_url` point to Supabase Storage or
   CDN; the client caches by URL (existing `image`/`gif_path` fields store the URL).

---

## 19. RLS Strategy

- **User-owned tables:** every row has `user_id`; policies:

  ```sql
  create policy "user owns rows"
  on public.workouts for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
  ```

  (`for all` = select/insert/update/delete; apply per table.)

- **`profiles` / `user_settings` (singletons):**

  ```sql
  create policy "user owns profile"
  on public.profiles for all
  using (id = auth.uid())
  with check (id = auth.uid());
  ```

- **Master tables:** authenticated users may read; writes restricted to service role
  (default-deny + no public write policy; only `service_role` / SQL admin publishes).
- **Realtime:** enabled only on user tables with the `user_id=eq.` filter.
- **Never expose `service_role` key to Flutter**; the app uses the anon/publishable key.
- Audit: use `auth.uid()` exclusively; never trust client-supplied `user_id` beyond
  the `with check` comparison.

---

## 20. Migration Sequence (implementation phases — not executed yet)

0. **Prep (this phase):** audit complete. No code changed.
1. **Config:** add `supabase_flutter`; add `--dart-define` config provider
   (`SUPABASE_URL`, `SUPABASE_ANON_KEY`); extend `.gitignore` for any env file.
2. **SQLite migration v15:** add `uuid`, `updated_at`, `deleted_at`, `row_version`,
   `synced` metadata columns to all syncable tables + new `sync_state` table + new
   `sync_event` columns (event_uuid, batch_id, device_id, base_version, expires_at).
3. **Supabase backend:** create schema (§10), RLS (§19), indexes, triggers,
   `master_data_versions`, Storage buckets (backup/photos), seed master catalogs.
4. **Auth swap:** implement `SupabaseAuthService`/repository behind `AuthRepository`;
   map errors to existing l10n keys; keep email-verification gate; remove Google
   auth (keep `GoogleSignInService` for Drive). Local offline accounts stay until
   Firebase is removed.
5. **Sync push:** implement `SupabaseSyncTransport implements SyncTransport`; wire
   into `SyncEngine` + `SyncController`; extend `SyncEventRecorder` coverage to all
   syncable DAOs (§2).
6. **Sync pull:** implement `IncrementalSyncService`/`SyncOrchestrator` (initial +
   incremental + resumable), per-entity high-water marks, conflict-safe apply (§16).
7. **Connectivity:** extend `NetworkInfo` with a real internet reachability probe;
   retry engine hooks on restore; graceful failure on request errors.
8. **Realtime:** enable channels after login; apply to SQFlite + providers (§17).
9. **Master data sync:** `master_data_versions` + chunked pull (§18); migrate
   seeders to consume remote catalogs; backfill `gif_url`/`image_url`.
10. **Photos:** move profile photos from local paths to Storage URLs (update
    `ProfilePhotoService` + `user_profile.photo_path` → `photo_url`).
11. **Backup (optional, later):** keep Drive backups; optionally add a Supabase
    Storage backup repository behind `BackupRepository`; address key-recovery
    strategy for cross-device encrypted backups.
12. **Retire Firebase:** only after auth + sync are proven stable; then remove
    `firebase_core`, `firebase_auth`, `google_sign_in` auth usage and
    `firebase_options.dart`.

---

## 21. Required Files to Create

Planned (not created in this phase) — under `lib/data/services/supabase/`,
`lib/data/datasources/remote/`, `lib/data/models/` etc.:

- `lib/core/network/internet_reachability.dart` — real internet probe.
- `lib/data/services/supabase/supabase_config.dart` — dart-define config (no secrets).
- `lib/data/services/supabase/supabase_auth_service.dart` — Supabase email/password auth (implements `AuthRepository` contract).
- `lib/data/services/supabase/supabase_sync_transport.dart` — `SyncTransport` implementation.
- `lib/data/services/supabase/supabase_realtime_service.dart` — channel/subscription management.
- `lib/data/services/sync/sync_orchestrator.dart` — push + pull orchestration, initial/incremental sync.
- `lib/data/services/sync/sync_puller.dart` — incremental pull + master catalog sync.
- `lib/data/services/sync/sync_state_store.dart` — per-entity high-water marks.
- `lib/data/datasources/remote/` — remote data source per syncable entity (or a generic `SupabaseRemoteDataSource`).
- `lib/data/models/sync_state_model.dart`, `lib/data/models/remote_*.dart` mappers.
- `lib/domain/repositories/sync_state_repository.dart` (+ impl).
- `lib/presentation/providers/sync_status_provider.dart` — richer sync status/progress for initial sync (non-blocking).
- `docs/supabase/migrations/` — SQL migration scripts (DDL, RLS, triggers, master data versions).
- `docs/supabase/rls_policies.sql` — RLS policies.

## 22. Required Files to Modify

- `lib/injection/dependency_injection.dart` — register Supabase client, transport,
  orchestrator, realtime service, remote sources.
- `lib/main.dart` — initialize Supabase client before `runApp` (alongside existing init).
- `lib/core/constants/app_constants.dart` — add sync constants (batch size, page size, reachability URL).
- `lib/data/datasources/local/app_database.dart` — **SQLite migration v15** (uuid/sync columns, `sync_state`).
- All syncable local DAOs (`lib/data/datasources/local/*.dart`) — record `SyncEventRecorder.record(...)` on create/update/delete (currently only 7 do).
- `lib/data/services/sync/sync_engine.dart` — wire real transport + conflict-safe pull apply; keep queue contract.
- `lib/data/services/sync/sync_event_recorder.dart` — extend payload with UUID/base_version.
- `lib/data/services/auth/auth_service.dart` / `auth_repository_impl.dart` — swap Firebase for Supabase behind the interface; remove Google auth path.
- `lib/data/models/app_user_model.dart` — map Supabase `User` instead of Firebase.
- `lib/presentation/providers/sync_providers.dart` — use orchestrator; expose initial-sync progress.
- `lib/presentation/providers/connectivity_provider.dart` — combine OS connectivity + reachability.
- `lib/presentation/screens/auth/login_screen.dart` / `register_screen.dart` — remove Google buttons (per requirements).
- `lib/domain/usecases/auth/sign_in_with_google_usecase.dart` (+ provider wiring) — remove.
- `lib/presentation/providers/auth_controller.dart` — drop `signInWithGoogle`, init Supabase session restore.
- `lib/presentation/screens/splash/splash_screen.dart` — initialize Supabase, trigger first/incremental sync.
- `lib/data/services/storage/profile_photo_service.dart` — Storage URL handling.
- `lib/data/services/food_seeder.dart` / `workout_seeder.dart` — pull-from-Supabase catalogs instead of (or in addition to) local constants.

## 23. Files That Must NOT Be Modified Unnecessarily

- **All screens under `lib/presentation/screens/**`** (except the two auth screens where
  Google buttons are removed) — preserve UI, animations, GIFs, styling, layout.
- **All theme code** (`lib/core/theme/`, `app.dart` theme wiring, dynamic color).
- **`lib/presentation/router/app_router.dart`** — keep routes/redirect logic; only
  touch if auth-provider swap requires it (it shouldn't).
- **All domain entities / repository interfaces** (`lib/domain/**`) — only additive
  changes (new `SyncStateRepository`), never renames/removals.
- **Existing models** (`lib/data/models/*.dart`) — extend mappers only where sync
  metadata is added.
- **Backup stack** (`lib/data/services/backup/`, `google_sign_in` Drive usage) —
  keep as-is in this phase.
- **`lib/firebase_options.dart`, `lib/data/services/firebase_service.dart`** — keep
  until Firebase is formally retired.
- **Security stack** (`lib/data/services/security/`, `lib/core/security/`) — keep.
- **Localization** (`lib/l10n/`, `l10n.yaml`) — additive keys only.
- **`lib/main.dart`** — minimal addition (Supabase init).

---

## Appendix A — Verification Checklist (for the implementation phase)

- [ ] `flutter analyze` passes with zero new issues.
- [ ] `flutter test` passes (existing suite untouched).
- [ ] Local writes render instantly with no network in the path.
- [ ] Push succeeds with real transport; queue shows `completed` + `synced_at`.
- [ ] Kill network mid-sync → ops stay `pending`, retry on restore.
- [ ] Two devices: create on A → appears on B (Realtime) and on restart (pull).
- [ ] Bulk master data publish → only changed catalogs downloaded.
- [ ] RLS: User B cannot read/write User A rows (verified with anon key).
- [ ] No `service_role`, DB password, or JWT secret in any source file or repo.
- [ ] Initial sync interrupted → resumes from the last high-water mark without duplicates.
