import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/utils/release_logger.dart';
import '../../core/utils/result.dart';
import '../../data/services/supabase/supabase_service.dart';
import '../../data/services/sync/sync_event_recorder.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../injection/dependency_injection.dart';

/// Status of the latest auth action triggered through [AuthController].
enum AuthActionStatus { idle, loading, success, error }

/// High-level session phase used by the router guard.
enum AuthPhase {
  /// Services are still bootstrapping / the persisted session is being
  /// restored on cold start.
  initializing,

  /// Nobody is signed in.
  unauthenticated,

  /// The user must verify their email before entering the app (either a
  /// signed-in-but-unverified account, or a fresh sign-up that is waiting for
  /// confirmation with no session yet).
  emailVerificationRequired,

  /// Signed in with a verified email.
  authenticated,
}

/// Holds the current user plus the status of the latest auth action.
class AuthState {
  const AuthState({
    this.status = AuthActionStatus.idle,
    this.failure,
    this.user,
    this.pendingVerificationEmail,
    this.initialized = false,
  });

  final AuthActionStatus status;
  final Failure? failure;
  final AppUser? user;

  /// Email address of an account that was just registered but still awaits
  /// email confirmation (Supabase issues no session until it is confirmed).
  final String? pendingVerificationEmail;

  /// Whether the persisted session has been restored at least once.
  final bool initialized;

  bool get isBusy => status == AuthActionStatus.loading;

  AuthPhase get phase {
    if (!initialized) return AuthPhase.initializing;
    final AppUser? current = user;
    if (current != null && current.isSignedIn) {
      return current.isEmailVerified
          ? AuthPhase.authenticated
          : AuthPhase.emailVerificationRequired;
    }
    if (pendingVerificationEmail != null) {
      return AuthPhase.emailVerificationRequired;
    }
    return AuthPhase.unauthenticated;
  }

  AuthState copyWith({
    AuthActionStatus? status,
    Failure? failure,
    bool clearFailure = false,
    AppUser? user,
    bool clearUser = false,
    String? pendingVerificationEmail,
    bool clearPendingVerificationEmail = false,
    bool? initialized,
  }) {
    return AuthState(
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      user: clearUser ? null : user ?? this.user,
      pendingVerificationEmail: clearPendingVerificationEmail
          ? null
          : pendingVerificationEmail ?? this.pendingVerificationEmail,
      initialized: initialized ?? this.initialized,
    );
  }
}

/// Central auth controller.
///
/// Owns the reactive current user (seeded synchronously from the repository
/// and kept in sync with the Supabase auth stream) and exposes every auth
/// action as a `Result`. Actions are guarded so duplicate requests while a
/// request is in flight are rejected.
class AuthController extends Notifier<AuthState> {  StreamSubscription<AppUser?>? _subscription;

  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    _subscription = repository.authStateChanges.listen(
      (AppUser? user) {
        SyncEventRecorder.setActiveUser(
          user?.isSignedIn == true ? user?.id : null,
        );
        state = state.copyWith(
          user: user,
          status: AuthActionStatus.idle,
          clearFailure: true,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        state = state.copyWith(
          status: AuthActionStatus.error,
          failure: FailureMapper.from(error),
        );
      },
    );
    ref.onDispose(() => _subscription?.cancel());

    // Seed immediately so redirect logic never has to wait for the stream.
    return AuthState(user: repository.currentUser);
  }

  /// Re-syncs the session after the app's services (Supabase) have been
  /// bootstrapped. Re-subscribes to the auth stream and re-reads the current
  /// user so a persisted session is picked up on cold start.
  Future<void> syncSession() async {
    final AuthRepository repository = ref.read(authRepositoryProvider);
    await _subscription?.cancel();
    _subscription = repository.authStateChanges.listen(
      (AppUser? user) {
        SyncEventRecorder.setActiveUser(
          user?.isSignedIn == true ? user?.id : null,
        );
        state = state.copyWith(
          user: user,
          status: AuthActionStatus.idle,
          clearFailure: true,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        state = state.copyWith(
          status: AuthActionStatus.error,
          failure: FailureMapper.from(error),
        );
      },
    );
    final AppUser? restored = await repository.getCurrentUser();
    state = state.copyWith(
      user: restored ?? AppUser.signedOut,
      initialized: true,
      status: AuthActionStatus.idle,
      clearFailure: true,
    );
  }

  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    if (state.isBusy) return _busyResult<AppUser>();
    devLog('[AUTH] signInWithEmail: checking network...');
    if (!await _hasNetwork()) return _offlineResult<AppUser>();
    devLog('[AUTH] signInWithEmail: network OK, setting loading');
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    devLog('[AUTH] signInWithEmail: calling usecase...');
    final Result<AppUser> result = await ref
        .read(signInWithEmailUsecaseProvider)
        .call(email: email, password: password);
    devLog(
      '[AUTH] signInWithEmail: usecase returned isSuccess=${result.isSuccess} failure=${result.failureOrNull?.code}',
    );
    await _finishAction(result);
    if (result.isSuccess) {
      await _startSecureSession(result.valueOrNull);
      await ref.read(appPreferencesRepositoryProvider).setRememberMe(rememberMe);
      state = state.copyWith(clearPendingVerificationEmail: true);
    }
    return result;
  }

  Future<Result<AppUser>> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (state.isBusy) return _busyResult<AppUser>();
    if (!await _hasNetwork()) return _offlineResult<AppUser>();
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    final Result<AppUser> result = await ref
        .read(signUpWithEmailUsecaseProvider)
        .call(name: name, email: email, password: password);
    await _finishAction(result);
    if (result.isSuccess) {
      final AppUser? user = result.valueOrNull;
      if (user != null && user.isSignedIn) {
        await _startSecureSession(user);
        state = state.copyWith(clearPendingVerificationEmail: true);
      } else {
        // The account was created but Supabase requires email confirmation and
        // issued no session yet. Remember the address for the verification
        // screen and never treat this account as authenticated.
        state = state.copyWith(
          pendingVerificationEmail: email.trim().toLowerCase(),
          initialized: true,
        );
      }
    }
    return result;
  }

  Future<Result<void>> sendVerificationEmail() async {
    if (state.isBusy) return _busyResult<void>();
    if (!await _hasNetwork()) return _offlineResult<void>();
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    final Result<void> result = await ref
        .read(sendEmailVerificationUsecaseProvider)
        .call(email: state.pendingVerificationEmail);
    await _finishAction(result);
    return result;
  }

  Future<Result<AppUser?>> refreshVerificationStatus() async {
    if (state.isBusy) return _busyResult<AppUser?>();
    if (!await _hasNetwork()) return _offlineResult<AppUser?>();
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    final Result<AppUser?> result =
        await ref.read(reloadUserUsecaseProvider).call();
    if (result.isSuccess) {
      state = state.copyWith(
        status: AuthActionStatus.success,
        user: result.valueOrNull,
        failure: null,
      );
    } else {
      state = state.copyWith(
        status: AuthActionStatus.error,
        failure: result.failureOrNull,
      );
    }
    return result;
  }

  Future<Result<void>> resetPassword({required String email}) async {
    if (state.isBusy) return _busyResult<void>();
    if (!await _hasNetwork()) return _offlineResult<void>();
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    final Result<void> result = await ref
        .read(resetPasswordUsecaseProvider)
        .call(email: email);
    await _finishAction(result);
    return result;
  }

  /// Changes the signed-in user's password. Requires a recent session; the
  /// server may reject it and the friendly error is surfaced through [Result].
  Future<Result<void>> changePassword({required String newPassword}) async {
    if (state.isBusy) return _busyResult<void>();
    if (!await _hasNetwork()) return _offlineResult<void>();
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    final Result<void> result = await ref
        .read(updatePasswordUsecaseProvider)
        .call(newPassword: newPassword);
    await _finishAction(result);
    return result;
  }

  Future<Result<void>> signOut() async {
    if (state.isBusy) return _busyResult<void>();
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    final Result<void> result = await ref.read(signOutUsecaseProvider).call();
    if (result.isSuccess) {
      await _endSecureSession();
      state = state.copyWith(
        status: AuthActionStatus.success,
        user: AppUser.signedOut,
        clearPendingVerificationEmail: true,
        failure: null,
      );
    } else {
      state = state.copyWith(
        status: AuthActionStatus.error,
        failure: result.failureOrNull,
      );
    }
    return result;
  }

  Future<Result<void>> deleteAccount() async {
    if (state.isBusy) return _busyResult<void>();
    if (!await _hasNetwork()) return _offlineResult<void>();
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    final Result<void> result =
        await ref.read(deleteAccountUsecaseProvider).call();
    if (result.isSuccess) {
      await _endSecureSession();
      state = state.copyWith(
        status: AuthActionStatus.success,
        user: AppUser.signedOut,
        clearPendingVerificationEmail: true,
        failure: null,
      );
    } else {
      state = state.copyWith(
        status: AuthActionStatus.error,
        failure: result.failureOrNull,
      );
    }
    return result;
  }

  /// Clears the pending-verification marker (e.g. when the user leaves the
  /// verification screen back to the login form).
  void clearPendingVerification() {
    state = state.copyWith(clearPendingVerificationEmail: true);
  }

  /// Records a fresh secure session so the splash screen can validate the
  /// session on the next launch (auto-login). Best-effort: a session failure
  /// must never fail the sign-in.
  Future<void> _startSecureSession(AppUser? user) async {
    if (user?.isSignedIn != true) return;
    try {
      await ref.read(sessionManagerProvider).startSession(user!.id);
    } catch (error, stackTrace) {
      devLog(
        '[AUTH] startSession failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Ends the current user's secure session on logout / account deletion so a
  /// later launch cannot auto-login. Never throws.
  Future<void> _endSecureSession() async {
    final AppUser? current = state.user;
    if (current?.isSignedIn != true) return;
    await ref.read(sessionManagerProvider).endSession(current!.id);
  }

  Future<void> _finishAction(Result<Object?> result) async {
    state = state.copyWith(
      status: result.isSuccess
          ? AuthActionStatus.success
          : AuthActionStatus.error,
      failure: result.failureOrNull,
    );
  }

  Future<bool> _hasNetwork() async {
    // Offline-first mode (no Supabase configuration) must not block local app
    // usage with a connectivity check; auth actions then fail gracefully with
    // authUnavailable.
    final SupabaseService supabase = ref.read(supabaseServiceProvider);
    if (!supabase.isReady) return true;
    try {
      return await ref.read(networkInfoProvider).isConnected;
    } catch (_) {
      return true;
    }
  }

  FailureResult<T> _busyResult<T>() =>
      const FailureResult(Failure(message: 'authBusy', code: 'busy'));

  FailureResult<T> _offlineResult<T>() => const FailureResult(
    Failure(message: 'connectivityOffline', code: 'offline'),
  );
}

/// Exposes the [AuthController] and its current [AuthState].
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);