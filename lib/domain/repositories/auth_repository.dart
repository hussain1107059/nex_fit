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

  /// Resends the verification email. [email] is used when the user is not
  /// signed in yet (email-confirmation flow).
  Future<void> sendEmailVerification({String? email});

  Future<AppUser?> reloadUser();

  Future<void> resetPassword(String email);

  /// Changes the signed-in user's password.
  ///
  /// Throws an [AuthException] when the current session is not recent enough
  /// to allow a password change or the new password is rejected.
  Future<void> updatePassword({required String newPassword});

  Future<void> signOut();

  /// Permanently deletes the signed-in authentication account.
  Future<void> deleteAccount();
}
