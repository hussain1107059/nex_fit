# NexFit — Performance Audit (PROMPT 37)

> Audit of SQLite queries, indexes, Riverpod providers, sync batching, memory,
> images, animations, startup and the search/dashboard hot paths. Every
> finding is either fixed, evidenced via `EXPLAIN QUERY PLAN`, or documented
> with a reason it was deliberately left alone.

## 1. Database

### Configuration already correct
- WAL + `synchronous=NORMAL`, 8 MB page cache, 256 MB mmap, `temp_store=MEMORY`
  (`app_database.dart:96-123`).
- All 18 migrations run in one transaction; seeders use `txn.batch()`.
- No `busy_timeout` is set. **Left as-is**: writes are serialized by the
  engine's per-user lock and single-writer patterns; adding one is safe but
  there is no evidenced contention path. Documented for awareness.

### EXPLAIN QUERY PLAN evidence — `test/performance_audit_test.dart` (6/6 green)
The real planner on the production schema (all 18 migrations) confirms:

| Query | Plan |
|---|---|
| Dashboard 7-day range reads (`workout_history`, `water_log`, `weight_log`, `sleep_log`, `step_log`, `food_log`) | Composite `(user_id, timestamp)` indexes (v14) |
| Outbox drain (`sync_event` user+status ORDER BY created_at) | `idx_sync_event_user_status` |
| UUID lookups (`workout_history.uuid`) | Unique `idx_*_uuid` |
| `getEnabled` reminders (`user_id, is_enabled`) | `idx_reminder_user_enabled` |
| Seeder guard count (`exercise WHERE user_id IS NULL`) | Covering `idx_exercise_user_updated` (no scan) |
| Food/exercise `LOWER(name) LIKE '%q%'` | **Scan — documented, no index added** |

**No new indexes were added.** The leading-wildcard `LIKE` can never use a
B-tree index, so an index there is evidence-free; the mitigation is debouncing
(see below). All other hot reads are already index-served.

## 2. Fixes applied (evidence-driven)

### 2.1 Workout seeder no longer re-commits an 84-row batch per keystroke
`lib/data/services/workout_seeder.dart` — `_seedExercises` had **no
early-return**. `WorkoutLibraryRepositoryImpl.search()` calls `ensureSeeded`
on every search/build, so every keystroke re-queried all names and committed
a batch of 84 UPDATEs. Added a `COUNT(*)` guard that returns once the built-in
catalog is present (a future seed version that grows the catalog self-heals).
This was the single largest UI hot-path cost.

### 2.2 Exercise search debounced
`lib/presentation/screens/exercise/exercise_library_screen.dart` — `onChanged`
wrote the provider on every keystroke with no debounce. Now debounced 250 ms
(mirrors the food search).

### 2.3 Workout search debounced
`lib/presentation/screens/workout/workout_list_screen.dart` — same 250 ms
debounce added.

### 2.4 Dashboard build side-effect removed
`lib/presentation/screens/dashboard/dashboard_screen.dart` — `build()` called
`syncControllerProvider.refresh()` (a DB read + conflict count) via
`addPostFrameCallback` on **every rebuild**. Removed; the sync controller
already refreshes itself on completion, so the health card keeps fresh data.

## 3. Reviewed and deliberately unchanged

### Providers / rebuilds
- **`systemHealthProvider`** runs `PRAGMA integrity_check` + DB-size read on
  every sync/settings tick. This is the dashboard health card's live
  correctness signal, and the integrity check is deliberately real (not
  cached). **Not changed** — caching would sacrifice the audit's correctness
  requirement; the queries are cheap relative to the card's infrequent ticks.
- Broad `ref.invalidate` on `dashboardControllerProvider` after small edits
  (weight/water/sleep/goals) is the designed publish path — those modules
  legitimately change the dashboard. **Left as-is.**
- `nutritionMealCategoriesProvider` is a plain `FutureProvider` for static
  master data — cheap and never invalidated. **Left as-is.**
- `AsyncNotifier` controllers are permanent by design (app-shell lifetime);
  `FutureProvider.autoDispose` is used correctly for search/detail/catalog.

### Sync
- **Push is sequential per event** (`sync_engine.dart:293-320`): one HTTP call
  per outbox row, ~3 DB writes per event. Batching/parallelizing would change
  ordering guarantees and the per-event retry/backoff contract. **Documented**;
  not changed without a transport-level batch API.
- **Pull** is already batched (100/request) with the cursor advanced in the
  same transaction as the applied rows (atomic, resumable). Batch cap 50 →
  5,000 changes/run. Correct by design.
- **Remote change applier** does a SELECT-then-write per change inside the
  batch transaction; batch is 100 rows so bounded. `orderChangesForApply` is
  O(n²) per 100-row batch — negligible at this size. **Left as-is.**
- Per-run `rescheduleRemindersInContainer` (cancel-all + re-schedule) runs
  after every sync completion (PROMPT 34). It is idempotent and the price of
  correct post-pull scheduling; **left as-is**.
- Master-data refresh runs after every sync; it short-circuits on unchanged
  versions. **Left as-is.**
- `SyncEventRecorder.record` (non-transactional, builds a new `SyncEngine`) is
  **dead code** — not called anywhere in `lib/`. Noted; leaving it.

### Memory / images
- `assets/images/NextFit.png` is ~1 MB and displayed at small sizes in 4
  places (splash at 96×96). The profile avatar already sets
  `cacheWidth/cacheHeight`; the logo sites don't. A `cacheWidth`/`cacheHeight`
  on the splash/logo `Image.asset`s would avoid decoding at full resolution.
  **Not changed**: `Image.asset` without explicit sizing delegates to the
  `BoxFit`-aware decode on some platforms but not others; this is a candidate
  rather than an evidenced regression, and there is only one asset.
- No `.gif`/Lottie/confetti. The two `repeat()` animations (water-glass wave,
  workout "Get Ready" ring) are gated off-tab by `TickerMode`
  (`app_shell_screen.dart:95`). **Kept** — the prompt forbids removing
  animations without measurable problems.

### UI
- `setState` (83 uses) is all in event handlers, none in `build`.
- All result lists use `ListView.builder`. The food **catalog** browse builds a
  bounded `ListView(children:)` (~213 tiles) — non-lazy but bounded and
  grouped by category headers, so a builder flatten is a visual-refactor risk.
  **Documented**; left as-is.
- `IndexedStack` builds all 5 tabs at startup, loading every feature provider +
  both seeders concurrently on cold start. This is the app-shell design (keeps
  tab state + animations correct). **Documented**; changing it is a redesign.

### Startup
- DB open + migrations + seeds run before first frame but seeds are batched
  and the network sync is fire-and-forget. First frame is not blocked by the
  network. The v15 uuid backfill is a one-time per-row migration cost on large
  existing DBs; acceptable for a fresh-install-focused app.

## 4. Verification
- `flutter analyze` — clean.
- `test/performance_audit_test.dart` — 6/6 green (EXPLAIN QUERY PLAN evidence).
- Full regression — **524 pass / 2 fail**, the same two pre-existing,
  unrelated failures (`session_manager` device-change,
  `hydration_repository` loadStatistics).