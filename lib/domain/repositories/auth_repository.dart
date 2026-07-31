import 'dart:async';

import '../entities/app_user.dart';

/// Contract for authentication operations.
/// Implemented by [AuthRepositoryImpl] in the data layer.
abstract interface class AuthRepository {
  Stream<AppUser?> get authStateChanges;

  /// Synchronously returns the current user, or [AppUser.signedOut] when
  /// nobody is signed in. Used to seed reactive state before the stream
  /// emits its first event.
  AppUser get currentUser;

  Future<AppUser?> getCurrentUser();

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<AppUser> signInWithGoogle();

  Future<void> sendEmailVerification();

  Future<AppUser?> reloadUser();

  Future<void> resetPassword(String email);

  Future<void> signOut();
}
