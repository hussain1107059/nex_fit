import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../services/auth/auth_service.dart';

/// Data layer implementation of [AuthRepository].
///
/// Authentication is served exclusively by Supabase Auth. There is no local
/// account fallback: a fake local identity must never appear as a valid
/// authenticated user. Existing signed-in users keep their locally cached
/// fitness data (SQFlite) regardless of connectivity, but new sign-up/sign-in
/// always requires the Supabase backend.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._authService,
    this._profileRepository,
  );

  final AuthService _authService;
  final UserProfileRepository _profileRepository;

  @override
  Stream<AppUser?> get authStateChanges => _authService.authStateChanges;

  @override
  AppUser get currentUser => _authService.currentUser ?? AppUser.signedOut;

  @override
  Future<AppUser?> getCurrentUser() async {
    return _authService.currentUser ?? AppUser.signedOut;
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final AppUser user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      if (user.isSignedIn) {
        await _ensureCloudProfile(user);
        await _persistProfile(user);
      }
      return user;
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final AppUser user = await _authService.signUpWithEmail(
        name: name,
        email: email,
        password: password,
      );
      // Email confirmation required: no session yet, so there is nothing to
      // persist until the user verifies and signs in.
      if (user.isSignedIn) {
        await _ensureCloudProfile(user);
        await _persistProfile(user);
      }
      return user;
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  @override
  Future<void> sendEmailVerification({String? email}) async {
    try {
      await _authService.sendEmailVerification(email: email);
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  @override
  Future<AppUser?> reloadUser() async {
    try {
      final AppUser? user = await _authService.reloadUser();
      if (user != null && user.isSignedIn) {
        await _profileRepository.saveProfile(user);
      }
      return user;
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _authService.updatePassword(newPassword: newPassword);
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _authService.deleteAccount();
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  /// Ensures a matching `public.profiles` row exists in Supabase. Idempotent.
  Future<void> _ensureCloudProfile(AppUser user) async {
    await _authService.ensureProfile(user);
  }

  /// Persists the signed-in user's profile locally and stamps the last login.
  Future<void> _persistProfile(AppUser user) async {
    if (!user.isSignedIn) return;
    await _profileRepository.saveProfile(
      user.copyWith(lastLogin: DateTime.now()),
    );
    await _profileRepository.updateLastLogin(user.id);
  }

  Never _toDomainError(Object error) {
    if (error is AppException) throw error;
    throw const AppException('errorUnknown', code: 'unknown');
  }
}