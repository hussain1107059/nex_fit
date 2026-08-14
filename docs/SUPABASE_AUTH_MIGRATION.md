# NexFit — Supabase Authentication Migration (Email/Password)

> **Phase 02 — Application code migrated.** This document records the migration of
> NexFit authentication from **Firebase Auth → Supabase Auth** (email/password only,
> with email verification). It is a companion to
> [SUPABASE_MIGRATION_VALIDATION.md](./SUPABASE_MIGRATION_VALIDATION.md) (database
> foundation) and [SUPABASE_OFFLINE_SYNC_ARCHITECTURE.md](./SUPABASE_OFFLINE_SYNC_ARCHITECTURE.md)
> (Phase 01 audit / sync plan).

- **Supabase project:** `https://jzbkhtposhxlbgiyrbqg.supabase.co`
- **SDK:** `supabase_flutter ^2.17.1` (GoTrue client, PKCE, auto-refreshing session)
- **Scope:** sign-up, email verification, login, forgot/reset password, session restore,
  logout. Google login is **not** implemented. Google Drive backup keeps its own
  `google_sign_in` session (untouched).
- **Local source of truth unchanged:** SQFlite remains the offline store; local cached
  fitness data stays available offline.

---

## 1. Design decisions

| Concern | Decision |
| --- | --- |
| Backend | Supabase Auth, email/password provider only |
| Email confirmation | **Required** (Supabase default). A fresh `signUp` returns **no session** until the address is verified. The app never treats an unverified account as authenticated. |
| Session persistence | GoTrue persists the session automatically; restored in `SplashScreen._bootstrap` → `syncSession()` |
| Offline local accounts | **Deprecated.** The previous fake `offline-…` / `dev-user` accounts are removed. A fake local identity can never appear as a valid Supabase user. New login/sign-up requires connectivity; an existing persisted session keeps working offline. |
| Google login | Removed from auth (no `signInWithGoogle` anywhere). `GoogleSignInService` is retained **only** for Drive backup. |
| Profile row | On successful sign-in/sign-up a `public.profiles` row is **upserted** (`onConflict: id`) so a profile always exists for the auth user. Idempotent & safe to retry. |
| Account deletion | GoTrue cannot delete a user client-side; `deleteAccount` invokes a **`delete-user` Edge Function** (server-side, service role). Until that function is created, the About screen reports a friendly failure. |
| Keys | `SUPABASE_URL` + `SUPABASE_ANON_KEY` (publishable key) injected via `--dart-define`. **No secrets in source.** |

---

## 2. Build-time configuration

Add the values to every run/build (do not commit the real key):

```bash
flutter run --dart-define=SUPABASE_URL=https://jzbkhtposhxlbgiyrbqg.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=<publishable-anon-key>
```

When the defines are missing the app boots offline-first: `SupabaseService.initialize()`
returns `false`, `isReady` stays `false`, and every auth action fails gracefully with
`authUnavailable` (localized). This matches the previous Firebase behaviour.

> **Android deep-link (email confirm + reset return):** to route confirmation/reset links
> back into the app, register an intent filter for a scheme (e.g. `nexfit://`) in
> `AndroidManifest.xml` and add `ios` universal links as needed. Then pass
> `emailRedirectTo`/`redirectTo` in `signUp`/`resetPasswordForEmail` if you want the
> in-app callback. This is optional — users can also verify in the browser and sign in.

---

## 3. Required Supabase Dashboard configuration (manual)

Already applied during the database phase (see validation doc):

- `public.profiles` exists, is RLS-protected, and has `insert`/`update` policies for the
  row owner — so the client-side upsert works with the **anon key**.

Still to configure (documented here because it is not part of the repo):

1. **Email (SMTP) provider** — Authentication → Providers → Email; enable "Confirm email";
   set a real SMTP sender so verification/reset emails are delivered.
2. **Site URL / Redirect URLs** — the confirmation & reset URLs must point at the app
   (or a site URL you control).
3. **`delete-user` Edge Function** — created via Dashboard → Edge Functions (or SQL), using
   the `service_role` key to `auth.admin.deleteUser(id)` for the authenticated caller.
   Until present, "Delete account" fails gracefully.

---

## 4. File changes (Firebase → Supabase)

### New files
- `lib/supabase_options.dart` — build-time `SUPABASE_URL` / `SUPABASE_ANON_KEY`.
- `lib/data/services/supabase/supabase_service.dart` — optional, once-only `initialize()`,
  `isReady`, `client`. Mirrors the old `FirebaseService` contract.

### Rewritten
- `lib/data/services/auth/auth_service.dart` — wraps GoTrue. Emails/passwords only.
  - `signInWithEmail` → `auth.signInWithPassword`
  - `signUpWithEmail` → `auth.signUp(data: {display_name})`; returns `AppUser.signedOut`
    when confirmation is required (no session issued)
  - `sendEmailVerification({email})` → `auth.resend(type: OtpType.email, …)` (works pre-session)
  - `reloadUser` → `auth.getUser()` (fresh `emailConfirmedAt`)
  - `resetPassword` → `auth.resetPasswordForEmail`
  - `signOut` → `auth.signOut()` (does **not** sign out Google Drive)
  - `deleteAccount` → `functions.invoke('delete-user')`
  - `ensureProfile(user)` → `profiles.upsert(…, onConflict: 'id')`
  - Supabase errors mapped to the existing l10n keys (see §6)
- `lib/data/models/app_user_model.dart` — `fromSupabase(User?)` (was `fromFirebase`).
  `isEmailVerified = emailConfirmedAt != null`.
- `lib/data/repositories/auth_repository_impl.dart` — offline/dev account fallback removed;
  `ensureProfile` + local profile persistence on success.
- `lib/presentation/providers/auth_controller.dart` — new `AuthPhase` enum and
  `AuthState.pendingVerificationEmail` + `initialized`; Google method removed;
  `_hasNetwork` now reads `supabaseServiceProvider`.
- `lib/presentation/router/app_router.dart` — `_resolveRedirect` keyed on `AuthPhase`
  (initializing / unauthenticated / emailVerificationRequired / authenticated).
- `lib/presentation/screens/auth/email_verification_screen.dart` — dual-mode: signed-in
  unverified (resend/refresh/sign-out) **and** pre-session pending (resend/back-to-login).
- `lib/presentation/screens/auth/login_screen.dart` / `register_screen.dart` — Google
  button + divider removed.
- `test/auth_repository_offline_test.dart` — rewritten for the Supabase behaviour.
- `pubspec.yaml` — `supabase_flutter ^2.17.1` added; `firebase_core` / `firebase_auth` removed.

### Updated wiring
- `lib/injection/dependency_injection.dart` — `supabaseServiceProvider` replaces
  `firebaseServiceProvider`; `AuthService(supabaseService: …)`; `signInWithGoogleUsecaseProvider`
  and its import removed; `AuthRepositoryImpl` no longer takes `SecureStorageService`.
- `lib/presentation/screens/splash/splash_screen.dart` — initializes `SupabaseService`
  instead of `FirebaseService`; Google Sign-In init kept for Drive backup.
- `lib/domain/repositories/auth_repository.dart` — `signInWithGoogle` removed;
  `sendEmailVerification({String? email})`.
- `lib/domain/usecases/auth/send_email_verification_usecase.dart` — accepts optional email.
- `lib/domain/usecases/auth/sign_in_with_google_usecase.dart` — **deleted**.

### Deleted
- `lib/data/services/firebase_service.dart`
- `lib/firebase_options.dart`

### Untouched (kept for Drive backup)
- `lib/data/services/auth/google_sign_in_service.dart`, `google_sign_in`,
  `googleapis`, `googleapis_auth`, `backup_*` services.

---

## 5. Email-verification flow

Supabase's "Confirm email" default means `signUp` returns a user **without a session**.
The app handles both regimes:

1. **Confirmation required (normal case)** — `AuthService.signUpWithEmail` returns
   `AppUser.signedOut`; `AuthController.signUpWithEmail` stores
   `pendingVerificationEmail`; the router phase becomes `emailVerificationRequired` and
   the register screen routes to `/email-verification`. The screen shows the address,
   offers **Resend** (`auth.resend`) and **Back to login**. After verifying, the user
   signs in normally → session issued → app opens.
2. **Confirmation disabled / already signed in but unverified** — the signed-in-unverified
   user is forced to `/email-verification` with **Resend**, **Refresh status**
   (`auth.getUser()`), and **Sign out**.

`AuthState.phase`:

| `initialized` | user | pending email | phase |
| --- | --- | --- | --- |
| false | any | any | `initializing` (router holds on splash) |
| true | signed-out | null | `unauthenticated` → login |
| true | signed-out | set | `emailVerificationRequired` |
| true | signed-in, unverified | – | `emailVerificationRequired` |
| true | signed-in, verified | – | `authenticated` → shell |

---

## 6. Error mapping (Supabase → l10n)

All thrown as `AuthException(<l10n key>)`; keys already exist in
`lib/core/utils/failure_message.dart` / the localized strings.

| Supabase signal | l10n key |
| --- | --- |
| `invalid login credentials` / 401 | `authWrongPassword` |
| `email not confirmed` | `authEmailVerificationFailed` |
| `already been registered` | `authEmailInUse` |
| `at least 6 characters` | `authPasswordTooShort` |
| `invalid email` / `unable to validate email` | `authEmailInvalid` |
| `user not found` | `authUserNotFound` |
| `not enabled` / `not allowed` | `authOperationNotAllowed` |
| 429 / `too many requests` / `rate limit` | `authTooManyRequests` |
| network (socket/client/timeout) | `errorNetwork` |
| anything else | `authGeneric` |

---

## 7. Verification

```bash
flutter pub get
flutter analyze            # No issues found
flutter test               # passes except a pre-existing, date-sensitive
                           # hydration_repository_test failure (verified on baseline)
flutter test test/auth_repository_offline_test.dart   # 5/5 pass
```

The rewritten repository tests prove:
- sign-in persists the local profile and upserts the cloud profile;
- auth errors propagate **without** any offline account fallback;
- sign-up awaiting confirmation returns a signed-out user and persists nothing;
- sign-out clears the session through the service;
- `sendEmailVerification` forwards the requested email.

## 8. Known limitations / remaining manual steps

1. **Email delivery** requires an SMTP provider + redirect config in the Dashboard (§3).
2. **`delete-user` Edge Function** must be created for account deletion (§3).
3. **Android deep link** for in-app confirmation/reset return is optional (§2).
4. Only **email/password** is supported now; OAuth (Google/Apple) was intentionally
   excluded per scope.
5. The pre-existing `hydration_repository_test` streak assertion failure is unrelated
   to this migration.
