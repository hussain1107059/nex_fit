# NexFit — Sync Security Audit

> PROMPT 24 deliverable. Ten checks that the offline-first sync layer never
> lets one user read, write, update or delete another user's data; never
> uploads PII, passwords or secrets; keeps `sync_state` local-only; keeps
> master data read-only; and never embeds a service-role key or logs tokens.
> RLS (Postgres row-level security) is assumed on the backend and is **never
> weakened** — the client and its contracts are verified to uphold the same
> boundaries. Companion to `NEXFIT_SYNC_IMPLEMENTATION_STATUS.md`.

## 1. Model

Two test users (`user-1`, `user-2`) each run the full sync stack on their own
SQLite database, sharing a single user-scoped cloud transport that enforces row
ownership exactly like Supabase RLS:

- a push may only write a row whose `user_id` equals the signed-in user; a
  foreign/leaked local row is **rejected** (`security_policy_violation`,
  terminal) and never lands in another tenant's store;
- a pull only ever returns the requesting user's change-feed entries.

## 2. The ten checks

| # | Check | Evidence |
|---|---|---|
| 1 | **Read isolation** — a user never pulls another user's changes | user-2's sync pulls 0 of user-1's rows; user-2's DB stays empty |
| 2 | **Write isolation** — a cross-user push is rejected and never lands in another tenant's store | a device holding a restored copy of user-2's data attempts a push as user-1; the ownership guard rejects it, the cloud store and change feed stay empty, and the event is terminal (`failedPermanent`) |
| 3 | **Update isolation** — one user's edits never reach another user | user-2 edits its row; user-1's next sync pulls 0 changes and its own row is untouched |
| 4 | **Delete isolation** — one user's delete never tombstones another user's row | user-2 deletes its row; user-1's sync pulls nothing and its row's `deleted_at` stays null |
| 5 | **`sync_state` local-only** — cursor state never syncs | cursor rows exist only in each device's DB; the cloud has no `sync_state` table, no such change-feed entries and no registry mapping |
| 6 | **Master data read-only** — no write path in master sync | source inspection: `SupabaseMasterDataTransport` has no `.insert/.upsert/.delete/.update` calls and `MasterDataTransport` exposes only `getVersions`/`pullRows`; hybrid catalogs filter to `user_id IS NULL` |
| 7 | **No service-role key in Flutter** — anon/publishable key only | `SupabaseService.initialize` passes `publishableKey:`; a recursive scan of `lib/` finds no `service_role` / `serviceRole` reference anywhere |
| 8 | **No PII columns in sync payloads** | every `localToCloud` mapping and foreign-key name is checked against email/phone/password/pin/token/session/secret/hash terms; `profiles` carries body/targets but never the auth email/password |
| 9 | **No passwords in payloads** | a live pushed row contains only `{id, user_id, row_version, deleted_at} ∪ mapping columns` — nothing sensitive |
| 10 | **No tokens, full uuids or secrets in logs** | a failing push + a succeeding sync run are captured through `Logger.root`; no message contains the full event uuid, `password`, `auth_token` or `secret` (uuids are truncated via `SyncLog.maskEventUuid`, errors via `ValueMasker`) |

## 3. Test evidence

- `flutter analyze` — clean.
- `test/sync_security_audit_test.dart` — **10/10 green**.
- Full regression after PROMPT 24: **434 pass / 2 fail** — both pre-existing
  and unrelated (`session_manager` device-change, `hydration_repository`
  loadStatistics).

## 4. Notes

- The local FK (`weight_log.user_id → users(id)`) already blocks cross-user
  rows at the database layer; check 2 additionally verifies the sync transport
  guard on top of it (a restored backup of another account is simulated by
  seeding that account's profile + row in the device DB).
- No production code was changed for this audit; no RLS policy was created,
  modified or removed. Server-side RLS remains the authoritative boundary and
  is assumed by the client contracts.