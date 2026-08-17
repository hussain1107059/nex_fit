import 'dart:async';

import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/release_logger.dart';
import '../../../domain/entities/app_user.dart';
import '../../models/app_user_model.dart';
import '../supabase/supabase_service.dart';

/// Wraps the Supabase GoTrue client and exposes the email/password auth
/// operations the app needs.
///
/// Every public method throws [AuthException] with a localization key as the
/// message so the UI layer can translate it directly. Google Drive backup keeps
/// its own [google_sign_in] session and is intentionally NOT touched here.
class AuthService {
  AuthService({
    required this.supabaseService,
    Logger? logger,
  }) : _logger = logger ?? Logger('AuthService');

  final SupabaseService supabaseService;
  final Logger _logger;

  supabase.SupabaseClient get _client => supabaseService.client!;

  void _ensureReady() {
    if (!supabaseService.isReady) {
      throw const AuthException('authUnavailable', code: 'supabase_unavailable');
    }
  }

  /// Emits the current authenticated user (or signed-out) on every auth event.
  Stream<AppUser?> get authStateChanges {
    try {
      _ensureReady();
      return _client.auth.onAuthStateChange
          .map(
            (supabase.AuthState change) =>
                AppUserModel.fromSupabase(change.session?.user),
          );
    } on AuthException {
      return const Stream.empty();
    }
  }

  /// Synchronously returns the current user from the restored session, or null
  /// when Supabase is not ready / nobody is signed in.
  AppUser? get currentUser {
    if (!supabaseService.isReady) return null;
    return AppUserModel.fromSupabase(_client.auth.currentSession?.user);
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureReady();
    try {
      final supabase.AuthResponse response = await _client.auth
          .signInWithPassword(email: email.trim(), password: password);
      final supabase.User? user = response.user;
      if (user == null) {
        throw const AuthException('authGeneric', code: 'no_user');
      }
      return AppUserModel.fromSupabase(user);
    } catch (error) {
      throw _toAuthException(error);
    }
  }

  Future<AppUser> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    _ensureReady();
    try {
      final supabase.AuthResponse response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, dynamic>{'display_name': name.trim()},
      );
      final supabase.User? user = response.user;
      if (user == null) {
        throw const AuthException('authGeneric', code: 'no_user');
      }
      // When email confirmation is required (the Supabase default) no session
      // is issued until the address is verified. The new account must NOT be
      // treated as authenticated yet; the UI shows the verification screen and
      // the user signs in normally afterwards.
      if (response.session == null) {
        return AppUser.signedOut;
      }
      return AppUserModel.fromSupabase(user);
    } catch (error) {
      throw _toAuthException(error);
    }
  }

  /// Resends the verification email. [email] is required when the user is not
  /// signed in yet (email-confirmation flow); otherwise it falls back to the
  /// current user's address.
  Future<void> sendEmailVerification({String? email}) async {
    _ensureReady();
    final String? target =
        (email != null && email.trim().isNotEmpty)
            ? email.trim()
            : _client.auth.currentUser?.email;
    if (target == null || target.isEmpty) {
      throw const AuthException('authUserNotFound', code: 'no_user');
    }
    try {
      await _client.auth.resend(type: supabase.OtpType.email, email: target);
    } catch (error) {
      throw _toAuthException(error);
    }
  }

  /// Fetches a fresh copy of the current user so verification state
  /// (emailConfirmedAt) reflects the latest server data.
  Future<AppUser?> reloadUser() async {
    _ensureReady();
    if (_client.auth.currentUser == null) {
      throw const AuthException('authUserNotFound', code: 'no_user');
    }
    try {
      final supabase.UserResponse response = await _client.auth.getUser();
      return AppUserModel.fromSupabase(response.user);
    } catch (error) {
      throw _toAuthException(error);
    }
  }

  Future<void> resetPassword(String email) async {
    _ensureReady();
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (error) {
      throw _toAuthException(error);
    }
  }

  /// Changes the signed-in user's password through GoTrue's `updateUser`.
  ///
  /// The server re-authenticates implicitly and rejects weak or expired
  /// sessions with a friendly [AuthException] (e.g. the recent-login window
  /// may require the user to sign in again before a password change).
  Future<void> updatePassword({required String newPassword}) async {
    _ensureReady();
    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
    } catch (error) {
      throw _toAuthException(error);
    }
  }

  Future<void> signOut() async {
    if (!supabaseService.isReady) return;
    try {
      await _client.auth.signOut();
    } catch (error, stackTrace) {
      // Best-effort: a failed network call must not block local session
      // teardown.
      _logger.warning('Supabase sign-out failed: $error', error, stackTrace);
    }
  }

  /// Permanently deletes the current account.
  ///
  /// The GoTrue client cannot delete an account; a "delete-user" Edge Function
  /// (server-side, using the service role) performs the deletion. A failure
  /// here (e.g. the function is not configured yet) surfaces as a friendly
  /// auth error.
  Future<void> deleteAccount() async {
    _ensureReady();
    try {
      await _client.functions.invoke('delete-user');
    } catch (error, stackTrace) {
      _logger.warning('Account deletion failed: $error', error, stackTrace);
      throw const AuthException('authGeneric', code: 'delete_account_failed');
    }
  }

  /// Upserts a row in `public.profiles` keyed by the auth user id so a profile
  /// always exists after sign-in/sign-up. Idempotent (`onConflict: id`) and
  /// safe to retry. Best-effort: a failure is logged but never blocks auth.
  Future<void> ensureProfile(AppUser user) async {
    if (!user.isSignedIn || !supabaseService.isReady) return;
    try {
      await _client.from('profiles').upsert(
        <String, dynamic>{
          'id': user.id,
          'display_name': user.displayName,
          'avatar_url': user.photoUrl,
        },
        onConflict: 'id',
      );
    } catch (error, stackTrace) {
      devLog(
        '[AUTH-SERVICE] ensureProfile failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      _logger.warning('ensureProfile failed: $error', error, stackTrace);
    }
  }

  AuthException _toAuthException(Object error) {
    devLog(
      '[AUTH-SERVICE] error: $error',
      error: error,
    );
    if (error is AuthException) return error;
    if (error is supabase.AuthException) {
      final String key = _mapAuthError(error);
      return AuthException(
        key,
        code: error.statusCode ?? 'supabase_auth_error',
      );
    }
    if (_isNetworkError(error)) {
      return const AuthException('errorNetwork', code: 'network_error');
    }
    return const AuthException('authGeneric', code: 'unknown_auth_error');
  }

  bool _isNetworkError(Object error) {
    final String text = error.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Connection refused') ||
        text.contains('Failed host lookup') ||
        text.contains('TimeoutException');
  }

  String _mapAuthError(supabase.AuthException error) {
    final String message = error.message.toLowerCase();
    final String? status = error.statusCode;
    if (message.contains('email not confirmed')) {
      return 'authEmailVerificationFailed';
    }
    if (message.contains('invalid login credentials')) {
      return 'authWrongPassword';
    }
    if (message.contains('already been registered') ||
        message.contains('already registered')) {
      return 'authEmailInUse';
    }
    if (message.contains('at least 6 characters')) {
      return 'authPasswordTooShort';
    }
    if (message.contains('invalid email') ||
        message.contains('unable to validate email')) {
      return 'authEmailInvalid';
    }
    if (message.contains('user not found')) {
      return 'authUserNotFound';
    }
    if (message.contains('not enabled') || message.contains('not allowed')) {
      return 'authOperationNotAllowed';
    }
    if (message.contains('too many requests') ||
        message.contains('rate limit')) {
      return 'authTooManyRequests';
    }
    if (status == '429') return 'authTooManyRequests';
    if (status == '401') return 'authWrongPassword';
    return 'authGeneric';
  }
}
