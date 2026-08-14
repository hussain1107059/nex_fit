# NexFit — Offline-First End-to-End Audit

> PROMPT 25 deliverable. A full user journey on top of the **real DAO layer**
> (the same local data sources the app reads and writes through) with a
> Supabase-like cloud and a network-flapping transport. Proves the app is fully
> usable offline, uploads nothing while offline, retains every mutation durably,
> and converges every device to the same state after reconnect. Companion to
> `NEXFIT_SYNC_IMPLEMENTATION_STATUS.md`.

## 1. Model

- **phone** (`phone.db`) — the device that produces the offline session. Its
  DAO writes run through `SyncEventRecorder` (configured for `user-1`,
  `device-phone`), so every mutation is committed atomically together with its
  outbox event.
- **tablet** (`tablet.db`) — a second device that never writes locally; it only
  pulls the cloud change feed and applies it.
- **cloud** — the same Supabase-like `_CloudStore` / `_FlappableTransport` model
  used by the PROMPT 23 validation: idempotent upserts keyed on the record
  uuid, optimistic `row_version` conditional writes, soft-delete tombstones and
  a keyset-paginated `sync_changes` feed. The transport can be `networkDown`
  (push + pull throw) or `failPullOnce` (a single pull drops mid-run).

## 2. The scenarios

| # | Scenario | Evidence |
|---|---|---|
| 1 | **Offline-first reads** — the app is fully usable offline | creates across six entity types (weight, food, water, sleep, steps, fitness goal, workout) plus one edit (weight → 81.0) and one delete (water) are recorded through the real DAOs; the read path (`getByUserId` / `getById`) immediately reflects every change from the local database; the outbox holds all 9 mutations pending |
| 2 | **Offline sync** — a "Sync now" run while offline uploads nothing | `sync()` with a `networkDown` transport reports failures; all 9 events are retained as `failedRetryable`, the cloud store stays empty |
| 3 | **Reconnect convergence** — everything uploads exactly once and a second device converges | after `_makeDue`, the same 9 events upload (7 creates + 1 update + 1 delete, `store.inserts == 7`, `changeCount == 9`); the tablet pulls all 9 and ends up with the edited weight (81.0), all created rows, and the deleted water row soft-deleted (tombstoned) |
| 4 | **Flapping network** — a push-succeeds/pull-fails run is a partial failure, a later retry recovers without duplicates | 3 weight rows pushed (3 cloud inserts), then the pull throws → `failed: 1`, `hasPulled: false`; retry on a healthy transport pushes nothing (`succeeded: 0`, `inserts` still 3) and the tablet ends with exactly the 3 rows — no duplicates anywhere |

## 3. Test evidence

- `flutter analyze` — clean.
- `test/offline_first_e2e_test.dart` — **3/3 green**.
- Full regression after PROMPT 25: **437 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).

## 4. Notes

- The DAO layer is the real app entry point: `WeightLogLocalDataSource`,
  `FoodLogLocalDataSource`, `WaterLogLocalDataSource`, `SleepLogLocalDataSource`,
  `StepLogLocalDataSource`, `FitnessGoalLocalDataSource` and
  `WorkoutLocalDataSource` — not raw SQL. This is why the journey is
  end-to-end rather than a transport-only simulation.
- No production code was changed for this audit; the only change in this prompt
  is the new test file and documentation.