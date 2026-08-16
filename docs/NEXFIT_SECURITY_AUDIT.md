# NexFit — Complete Application Security Audit

> PROMPT 38 deliverable. A full client-side security audit of NexFit: auth &
> session handling, local storage, the offline-first sync layer, network
> posture, logging, Android OS-level data protection and dependency risk.
> Findings are severity-ordered (Critical / High / Medium / Low / Informational)
> with a clear **fixed** vs **by design / documented** verdict. Companion to
> `NEXFIT_SYNC_SECURITY_AUDIT.md` (PROMPT 24, sync isolation) and
> `NEXFIT_PRODUCTION_READINESS.md` (PROMPT 26).

## 0. Scope and method

- Client-only audit (this repo has no server code; the Supabase project is
  provisioned via SQL migrations in `supabase/` and Dashboard Edge Functions).
- Method: source inspection across `lib/`, the resolved `pubspec.lock`
  dependency graph, Android OS-level settings, and the test evidence.
- Verified with `flutter analyze` (clean) and the full regression suite
  (**530 pass / 2 fail**, both pre-existing and unrelated: `session_manager`
  device-change, `hydration_repository` loadStatistics).
- Server-side RLS remains the **authoritative** multi-tenant boundary; the
  client enforces the same rules as defense-in-depth.

## 1. Severity summary

| # | Severity | Finding | Verdict |
|---|---|---|---|
| 1 | **High** | Supabase JWT session (access + refresh token) persisted in **plaintext SharedPreferences** | **FIXED** — routed through flutter_secure_storage |
| 2 | **High** | App-lock PIN hashed with SHA-256 + static public salt (offline-brute-forceable) | **FIXED** — PBKDF2-HMAC-SHA256 + random salt, legacy hashes upgraded |
| 3 | **High** | Lock screen has no rate limiting / lockout | **FIXED** — escalating retry delay after 5 failures |
| 4 | **Medium** | `SupabaseSyncTransport._requireUserId` never compared the event user to the session user (dead parameter) | **FIXED** — client guard now rejects cross-user pushes |
| 5 | **Medium** | Android OS-level Auto Backup enabled by default (exports SharedPreferences incl. JWT + unencrypted DB) | **FIXED** — `allowBackup=false` + `dataExtractionRules`/`fullBackupContent` exclude everything |
| 6 | **Low** | Full user UUIDs / record ids logged unmasked in sync, session and Realtime logs | **FIXED** — `SyncLog.maskUserId` + masked Realtime ids |
| 7 | **Low** | Legacy dead token keys (`authToken`, `refreshToken`, `googleAccessToken`, `googleRefreshToken`) | **FIXED** — removed |
| 8 | **Low** | `.env` files not excluded from version control | **FIXED** — `*.env`/`.env.*` added to `.gitignore` |
| 9 | **Medium** | Local SQFlite DB not encrypted at rest (SQLCipher absent) | **By design** — documented below |
| 10 | **Medium** | App-level session token stored plaintext in `sessions` table | **By design** — documented below |
| 11 | **Low** | Account deletion leaves local data (cloud wipe depends on deployed Edge Function) | **By design** — documented below |
| 12 | **Low** | Logout does not clear secure storage / local DB | **By design** — offline-first |
| 13 | **Info** | Only 2 of ~20 DAOs enforce client-side `isCurrentUser`; guard passes when signed out | **By design** — server RLS authoritative |
| 14 | **Info** | `event_uuid` is not sent to the server; push dedupe keys on record uuid | **By design** — documented below |
| 15 | **Info** | Raw server error messages can appear in debug-only logs | **By design** — release builds emit no logs |

## 2. Fixed findings (PROMPT 38)

### 2.1 HIGH — Supabase session no longer in plaintext SharedPreferences
**Before:** `Supabase.initialize` used the supabase_flutter default
`SharedPreferencesLocalStorage`, which writes the full GoTrue session JSON —
including the access and refresh tokens — to plaintext SharedPreferences
(Android internal storage, extractable by anyone with device access / a
backup copy).

**After:** `lib/data/services/supabase/secure_local_storage.dart` implements the
`LocalStorage` contract over flutter_secure_storage (Android Keystore / iOS
Keychain / DPAPI), and `supabase_service.dart:35-47` passes it via
`authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage())`.
The session now lives in the OS keychain.

### 2.2 HIGH — PIN hashing upgraded to PBKDF2 with a random salt
**Before:** `settings_providers.dart` hashed the PIN as SHA-256 over
`nexfit.app.lock.v1:<pin>` — a static, public salt. A 4-digit PIN (10,000
combos) is offline-brute-forceable from the stored hash in minutes on a
modern GPU.

**After:** `lib/data/services/security/pin_hasher.dart`:
- PBKDF2-HMAC-SHA256, 120,000 iterations, random 16-byte salt per PIN;
- stored as `nk2:<iterations>:<saltB64>:<hashB64>`;
- constant-time comparison;
- **backward compatible**: a legacy hash is still verified, and on the next
  successful unlock `verifyPin` re-hashes it in place to the versioned format
  (`settings_providers.dart:253-263`), so no existing user is locked out;
- `test/security_hardening_test.dart` (6/6) locks in format, tamper rejection,
  legacy verification and uniqueness.

### 2.3 HIGH — Lock screen escalating retry delay
**Before:** unlimited PIN attempts, no delay.

**After:** `lock_screen.dart` counts consecutive failures (in-memory,
documented as a rapid-brute-force deterrent rather than a cryptographic
guarantee). After 5 failures the pad disables with an escalating delay —
30 s (5), 1 min (6), 2 min (8), 5 min (10+) — shown via a live countdown
(`settingsLockTooManyAttempts` l10n key, both ARBs). `PinPad`/`_KeyButton`
gained an `enabled` flag that visually dims and disables input during the
lockout. The 700 ms wrong-PIN clear timer still applies below the threshold.

### 2.4 MEDIUM — Client-side cross-user push guard
`supabase_sync_transport.dart:51-70`: `_requireUserId` now throws
`security_policy_violation` (non-retryable → `failedPermanent`) when the
event's `user_id` does not match `currentSession.user.id`, instead of only
checking that *some* session exists. Server-side RLS remains authoritative;
this closes the gap before a cross-user write is even attempted.

### 2.5 MEDIUM — Android OS-level backup disabled
`AndroidManifest.xml`: `android:allowBackup="false"` plus
`dataExtractionRules="@xml/data_extraction_rules"` and
`fullBackupContent="@xml/backup_rules"`. Both new XML files exclude every
domain (database, sharedpref, root, file, external, device_encrypted,
device_protected) from **cloud backup and device-to-device transfer**. This
stops Android Auto Backup from silently exporting the unencrypted SQLite DB
(which holds fitness PII, PIN hashes and session tokens) or the
SharedPreferences to Google Drive. The app's own Google Drive backup feature is
unaffected — it encrypts user data explicitly with AES-256-GCM.

### 2.6 LOW — Log masking of user ids
Added `SyncLog.maskUserId` and applied it to every `user=$userId` log site in
`sync_engine.dart`, `supabase_sync_transport.dart` and
`session_manager.dart`; Realtime record ids (which equal the user id for
singleton tables) now go through `SyncLog.maskEventUuid`
(`realtime_sync_notifier.dart:57-62`). Debug logs no longer expose full account
UUIDs. Release builds emit no logs at all (`configureLogging`).

### 2.7 LOW — Cleanups
- Removed the four dead legacy token keys from `StorageKeys` (verified unused
  across `lib/` and `test/`).
- `.gitignore` now excludes `*.env` and `.env.*`.

## 3. Findings left by design (with rationale)

### 3.1 MEDIUM — Unencrypted SQLite at rest
The local DB (`openDatabase`, no SQLCipher) holds fitness PII, PIN hashes and
session tokens at rest. **Rationale:** the offline-first architecture requires
SQLite; SQLCipher would be a large dependency + migration and is not in the
prompt's scope. Mitigations already present: field-level AES-256-GCM
encryption for the most sensitive columns (`FieldEncryption`), app-lock,
screenshot lock, FLAG_SECURE, and now (2.5) OS backup disabled. Recommended
follow-up for a future hardening pass: SQLCipher or at-rest DB encryption.

### 3.2 MEDIUM — `sessions.token` plaintext in SQLite
The app-level session token (48 random hex chars from `Random.secure()`) is
stored plaintext. **Rationale:** it is device-local, random, scoped to one
session, and validated with a device-id + expiry check; the risk is covered by
the OS-backup fix and device access being required in the first place. The
Supabase JWT (the real long-lived credential) is now in the keychain (2.1).

### 3.3 LOW — Account deletion does not wipe local data
`deleteAccount` calls the `delete-user` Edge Function (server-side, service
role) and ends the secure session, but does not wipe the local DB. **Rationale:**
offline-first design; a separate "delete local data" action
(`settings_providers.dart:315-329`) wipes the user's local rows on demand. The
Edge Function is deployed via the Supabase Dashboard and is not in this repo.

### 3.4 LOW — Logout does not clear secure storage / DB
Encryption keys, device id and backup key survive logout (only
`sessions`/session state is deactivated). **Rationale:** offline-first — the
same device may sign back in and must reuse its encryption keys; clearing them
would make field-encrypted data unrecoverable.

### 3.5 Info — Client-side ownership guards in only 2 of ~20 DAOs
`food_item` and `exercise` enforce `isCurrentUser`; the rest rely on the caller
passing the authenticated user id. **Rationale:** the guard also passes when
signed out, so it is weak anyway; the definitive boundary is server RLS
(`WITH CHECK (user_id = auth.uid())`), which blocks every cross-user write.

### 3.6 Info — `event_uuid` not sent to the server
Push dedupe keys on the record uuid upsert (`onConflict: 'id'`), not on
`event_uuid`. **Rationale:** retried events reuse the same record uuid, so a
duplicate cloud row is impossible; the event uuid is a local idempotency
marker. No functional gap found.

### 3.7 Info — Raw server error messages in debug-only logs
Postgrest / master-data / coordinator error paths log `error.message` (and
`AppErrorLogger` console `severe` logs the raw exception). **Rationale:**
`configureLogging()` attaches no listener in release, so nothing is emitted in
production; debug logs are developer-only. `ValueMasker` is already applied to
persisted error logs. No password/token/session values are ever logged.

## 4. Confirmed-strong controls

- **No secrets in the repo.** No `.env`, no hardcoded keys. Supabase URL, anon
  key and Google client id are injected at build time via `--dart-define`
  (`supabase_options.dart`); the service-role key appears nowhere in `lib/` or
  `test/` (enforced by `sync_security_audit_test.dart` #7).
- **Anon/publishable key only** for Supabase; all data calls ride the user's
  JWT through RLS-protected endpoints. Master-data transport has no write path
  (`sync_security_audit_test.dart` #6).
- **Sync isolation** (PROMPT 24, 10/10): read/write/update/delete isolation
  across users, `sync_state` local-only, per-user cursors.
- **SQL-injection safe**: strict column allow-lists in `SyncTableRegistry`,
  parameterized SQL, no interpolation of network data
  (`remote_change_applier.dart`).
- **Email verification enforced** at the router guard; password reset and
  account deletion delegate to server flows with no token leakage.
- **Cryptographically-strong UUIDs** (`Random.secure()`, v4) with unique
  indexes.
- **Release-safe logging**: `devLog` tree-shaken, `configureLogging` emits
  nothing in release.
- **Current dependencies**: all top-10 runtime packages resolve to current
  stable lines (supabase_flutter 2.17.1, flutter_local_notifications 19.5.0,
  crypto 3.0.7, sqflite 2.4.3, http 1.6.0, go_router 17.3.0); `intl` 0.20.2
  pinned (the only exact constraint); no git/remote sources, no deprecated
  packages found.
- **Field encryption keys, device id and backup key** already live in the OS
  keychain (flutter_secure_storage).

## 5. Verification

- `flutter analyze` — clean.
- `test/security_hardening_test.dart` — **6/6 green** (PIN PBKDF2).
- `test/sync_security_audit_test.dart` — **10/10 green** (sync isolation +
  static contract checks, including "no tokens/full uuids in logs").
- Full regression — **530 pass / 2 fail**, both pre-existing and unrelated
  (`session_manager` device-change, `hydration_repository` loadStatistics).
- OS-level: manifest + backup/transfer rules compile (no analyzer surface;
  verified by file presence and Android resource rules).

## 6. Recommended residual follow-ups (outside this prompt's scope)

1. **At-rest DB encryption** (SQLCipher) or platform-native encrypted DB —
   closes the main remaining Medium (3.1).
2. **Persist the lockout counter** across app restarts so the escalating delay
   survives a process kill (today it is in-memory by design, 2.3).
3. **Live-Supabase integration smoke suite** with staging credentials (G1 from
   `NEXFIT_PRODUCTION_READINESS.md`) — validates RLS + Realtime against the
   real project.
4. **Server-side audit** of the `delete-user` Edge Function (it receives the
   service role) and the RLS policy set in the deployed project.