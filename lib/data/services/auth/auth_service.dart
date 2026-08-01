import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logging/logging.dart';

import '../../../core/errors/app_exception.dart';
import '../firebase_service.dart';
import 'google_sign_in_service.dart';

/// Wraps [FirebaseAuth] and exposes the auth operations the app needs.
///
/// Every public method throws [AuthException] with a localization key as
/// the message so the UI layer can translate it directly.
class AuthService {
  AuthService({
    required this.firebaseService,
    required this.googleSignInService,
    Logger? logger,
  }) : _logger = logger ?? Logger('AuthService');

  final FirebaseService firebaseService;
  final GoogleSignInService googleSignInService;
  final Logger _logger;

  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;

  void _ensureReady() {
    if (!firebaseService.isReady) {
      throw const AuthException('authUnavailable', code: 'firebase_unavailable');
    }
  }

  Stream<fb.User?> get authStateChanges {
    try {
      _ensureReady();
      return _auth.authStateChanges();
    } on AuthException {
      return const Stream.empty();
    }
  }

  fb.User? get currentUser {
    if (!firebaseService.isReady) return null;
    return _auth.currentUser;
  }

  Future<fb.User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureReady();
    try {
      final fb.UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error), code: error.code);
    }
  }

  Future<fb.User?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    _ensureReady();
    try {
      final fb.UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fb.User? user = credential.user;
      if (user != null) {
        if (name.trim().isNotEmpty) {
          await user.updateDisplayName(name.trim());
        }
        // New accounts must verify their email before entering the app.
        try {
          await user.sendEmailVerification();
        } catch (error, stackTrace) {
          _logger.warning(
            'Failed to send verification email: $error',
            error,
            stackTrace,
          );
        }
      }
      return user;
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error), code: error.code);
    }
  }

  Future<fb.User?> signInWithGoogle() async {
    _ensureReady();
    try {
      final GoogleSignInAccount account =
          await googleSignInService.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException(
          'authGoogleSignInFailed',
          code: 'missing_id_token',
        );
      }

      final fb.OAuthCredential credential =
          fb.GoogleAuthProvider.credential(idToken: idToken);

      final fb.UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      return userCredential.user;
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error), code: error.code);
    } on AuthException {
      rethrow;
    } catch (error) {
      _logger.warning('Google sign-in failed', error);
      throw const AuthException(
        'authGoogleSignInFailed',
        code: 'google_sign_in_failed',
      );
    }
  }

  Future<void> sendEmailVerification() async {
    _ensureReady();
    final fb.User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('authUserNotFound', code: 'no_user');
    }
    try {
      await user.sendEmailVerification();
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error), code: error.code);
    }
  }

  /// Reloads the current user profile so verification state is fresh.
  Future<fb.User?> reloadUser() async {
    _ensureReady();
    final fb.User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('authUserNotFound', code: 'no_user');
    }
    try {
      await user.reload();
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error), code: error.code);
    }
    return _auth.currentUser;
  }

  Future<void> resetPassword(String email) async {
    _ensureReady();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error), code: error.code);
    }
  }

  Future<void> signOut() async {
    if (!firebaseService.isReady) return;
    await Future.wait([
      _auth.signOut(),
      googleSignInService.signOut(),
    ]);
  }

  /// Permanently deletes the current Firebase account.
  Future<void> deleteAccount() async {
    _ensureReady();
    final fb.User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('authUserNotFound', code: 'no_user');
    }
    try {
      await user.delete();
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error), code: error.code);
    }
  }

  String _mapAuthError(fb.FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'authEmailInvalid',
      'user-not-found' => 'authUserNotFound',
      'wrong-password' => 'authWrongPassword',
      'email-already-in-use' => 'authEmailInUse',
      'weak-password' => 'authPasswordTooShort',
      'user-disabled' => 'authUserDisabled',
      'too-many-requests' => 'authTooManyRequests',
      'operation-not-allowed' => 'authOperationNotAllowed',
      'network-request-failed' => 'errorNetwork',
      'account-exists-with-different-credential' =>
        'authAccountExistsWithDifferentCredential',
      'popup-closed-by-user' => 'authCancelled',
      'cancelled-popup-request' => 'authCancelled',
      'unknown' => 'authGeneric',
      _ => 'authGeneric',
    };
  }
}
