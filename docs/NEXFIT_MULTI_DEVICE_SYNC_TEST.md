# NexFit — Multi-Device Sync Test

> PROMPT 23 deliverable. Validates the offline-first two-way sync engine against
> **two logical devices backed by two separate SQLite databases** sharing one
> Supabase-like cloud store. Companion to `NEXFIT_TWO_WAY_SYNC_ARCHITECTURE.md`
> and `NEXFIT_SYNC_IMPLEMENTATION_STATUS.md`.

## 1. Model

Each logical device is a full sync stack on its own physical database:

| Component | Device A | Device B |
|---|---|---|
| SQLite file | `a.db` | `b.db` |
| `AppDatabase` | `AppDatabase(databaseName: 'a.db')` | `AppDatabase(databaseName: 'b.db')` |
| Outbox (`sync_event`) | own table | own table |
| Pull cursor (`sync_state`) | own cursor | own cursor |
| Conflict store (`sync_conflict`) | own table | own table |
| Device id | `device-a` | `device-b` |

The **cloud** is a single in-memory `_CloudStore` shared by both devices'
transports. It mirrors Supabase behaviour:

- **Idempotent upserts** keyed on the row's `uuid` (`onConflict: 'id'`), so a
  retried event can never create a duplicate row.
- **Optimistic concurrency** via `row_version`: writes are conditional on the
  event's `base_version`; a stale write returns a conflict with the server
  snapshot.
- **Soft-delete tombstones** (`deleted_at`) instead of hard deletes.
- **Keyset-paginated `sync_changes` feed** (`id` cursor, `limit`), per user.

The `AppDatabase` gained an optional `databaseName` constructor parameter so a
test (or multi-DB deployment) can open separate physical stores without
changing any default behaviour.

## 2. Scenarios

### 1. Workout created on device A appears on device B
A creates a workout and syncs; the cloud has 1 `workouts` row. B syncs and the
pulled row lands in B's own database with the same `name` and `uuid`.

### 2. Workout edited on device B propagates back to device A
After B pulls A's workout (local `row_version` 1), B edits it (base version 1)
and syncs. The optimistic write succeeds (cloud 1 → 2) and A converges to
`name = "Push Day v2"`, `row_version = 2` through the pull.

### 3. Food logged while offline is retained, uploaded later, reaches device B
A logs a food entry while `networkDown` (push throws a retryable transport
error). The event is retained as `failedRetryable` in the outbox — **never
dropped** — and nothing reaches the cloud. When the network returns the backoff
elapses, the event uploads exactly once and B sees `fl-1` (calories 350).

### 4. Concurrent edits on A and B → SERVER_WINS conflict
Both devices edit the same `weight_log` based on version 1. A syncs first and
wins the optimistic lock (cloud 1 → 2, weight 81.0). B's stale write
(`base_version` 1 ≠ cloud 2) conflicts; the default `latestWins` resolves as
**SERVER_WINS** — B's event completes, the pull overwrites B's row with the
server value (81.0), and a durable conflict record is stored on B. B's stale
83.0 edit is never silently lost.

### 5. Delete on device A applies a soft-delete tombstone on device B
A tombstones the row (delete event, base version 1). The cloud row keeps a
`deleted_at` timestamp (not hard-deleted); B pulls the DELETE change and applies
the tombstone to its local row.

### 6. 100 offline records upload exactly once
A queues 100 `weight_log` creates while offline — all retained as
`failedRetryable`. Back online, all 100 upload: the cloud holds exactly 100
rows and `store.inserts == 100`. A second sync processes **0** events and adds
**no** new cloud rows (no duplicates).

### 7. 1000 remote changes are pulled incrementally with a per-batch cursor
The cloud is seeded with 1000 pre-existing rows/changes. B pulls them across
10 batches of 100, applies all 1000 into its own database and lands the cursor
at 1000. The next sync pulls **0** changes with a stable cursor.

### 8. Kill-and-restart: a committed-but-timed-out push is recovered
A's first push **commits server-side then times out** before the ack (models
the app being killed mid-request). The event becomes `failedRetryable`
(retry 1). After restart (fresh engine, same DB) and backoff, the retry is an
idempotent upsert: **no duplicate cloud row** (`inserts` stays 1), the event
completes, and B pulls the recovered record.

## 3. Invariants asserted

- Separate physical stores: A and B never share `sync_event` / `sync_state` /
  `sync_conflict` rows.
- Every outbox event carries the creating device's `device_id`
  (`device-a` / `device-b`).
- A committed cloud mutation is never repeated (`store.inserts` unchanged on
  retry) — the idempotency key is the record `uuid`.
- A pull cursor never advances past unapplied rows (1000/1000 applied with
  cursor 1000).
- Conflicts are durable and resolve SERVER_WINS by default without silently
  discarding the stale local edit.
- Offline mutations are durable in the outbox (retryable, not dropped).

## 4. Test evidence

- `flutter analyze` — clean.
- `test/multi_device_sync_test.dart` — **8/8 green**.
- Full regression after PROMPT 23: **424 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).