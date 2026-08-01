import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../injection/dependency_injection.dart';

/// Status of the latest auth action triggered through [AuthController].
enum AuthActionStatus { idle, loading, success, error }

/// Holds the current user plus the status of the latest auth action.
class AuthState {
  const AuthState({
    this.status = AuthActionStatus.idle,
    this.failure,
    this.user,
  });

  final AuthActionStatus status;
  final Failure? failure;
  final AppUser? user;

  bool get isBusy => status == AuthActionStatus.loading;

  AuthState copyWith({
    AuthActionStatus? status,
    Failure? failure,
    AppUser? user,
    bool clearFailure = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      user: user ?? this.user,
    );
  }
}

/// Central auth controller.
///
/// Owns the reactive current user (seeded synchronously from the repository
/// and kept in sync with the Firebase auth stream) and exposes every auth
/// action as a `Result`. Actions are guarded so duplicate requests while a
/// request is in flight are rejected.
class AuthController extends Notifier<AuthState> {  StreamSubscription<AppUser?>? _subscription;

  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    _subscription = repository.authStateChanges.listen(
      (AppUser? user) {
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

  /// Re-syncs the session after the app's services (Firebase) have been
  /// bootstrapped. Re-subscribes to the auth stream and re-reads the current
  /// user so a persisted session is picked up on cold start.
  Future<void> syncSession() async {
    final AuthRepository repository = ref.read(authRepositoryProvider);
    await _subscription?.cancel();
    _subscription = repository.authStateChanges.listen(
      (AppUser? user) {
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
    state = state.copyWith(
      user: repository.currentUser,
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
    debugPrint('[AUTH] signInWithEmail: checking network...');
    if (!await _hasNetwork()) return _offlineResult<AppUser>();
    debugPrint('[AUTH] signInWithEmail: network OK, setting loading');
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    debugPrint('[AUTH] signInWithEmail: calling usecase...');
    final Result<AppUser> result = await ref
        .read(signInWithEmailUsecaseProvider)
        .call(email: email, password: password);
    debugPrint(
      '[AUTH] signInWithEmail: usecase returned isSuccess=${result.isSuccess} failure=${result.failureOrNull?.code}',
    );
    await _finishAction(result);
    if (result.isSuccess) {
      await ref.read(appPreferencesRepositoryProvider).setRememberMe(rememberMe);
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
    return result;
  }

  Future<Result<AppUser>> signInWithGoogle() async {
    if (state.isBusy) return _busyResult<AppUser>();
    if (!await _hasNetwork()) return _offlineResult<AppUser>();
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    final Result<AppUser> result =
        await ref.read(signInWithGoogleUsecaseProvider).call();
    await _finishAction(result);
    return result;
  }

  Future<Result<void>> sendVerificationEmail() async {
    if (state.isBusy) return _busyResult<void>();
    if (!await _hasNetwork()) return _offlineResult<void>();
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    final Result<void> result =
        await ref.read(sendEmailVerificationUsecaseProvider).call();
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

  Future<Result<void>> signOut() async {
    if (state.isBusy) return _busyResult<void>();
    state = state.copyWith(status: AuthActionStatus.loading, failure: null);

    final Result<void> result = await ref.read(signOutUsecaseProvider).call();
    if (result.isSuccess) {
      state = state.copyWith(
        status: AuthActionStatus.success,
        user: AppUser.signedOut,
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
      state = state.copyWith(
        status: AuthActionStatus.success,
        user: AppUser.signedOut,
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

  Future<void> _finishAction(Result<Object?> result) async {
    state = state.copyWith(
      status: result.isSuccess
          ? AuthActionStatus.success
          : AuthActionStatus.error,
      failure: result.failureOrNull,
    );
  }

  Future<bool> _hasNetwork() async {
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

