import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/errors/app_exception.dart';
import '../models/app_user_model.dart';
import '../services/auth/auth_service.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Dev-only credentials accepted when Firebase is unavailable.
const String _devTestEmail = 'test@gmail.com';
const String _devTestPassword = '123456';

/// Data layer implementation of [AuthRepository].
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._authService, this._profileRepository);

  final AuthService _authService;
  final UserProfileRepository _profileRepository;

  final StreamController<AppUser?> _devController =
      StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _devUser;

  bool get _isOffline => !_authService.firebaseService.isReady;

  @override
  Stream<AppUser?> get authStateChanges => _isOffline
      ? _devController.stream
      : _authService.authStateChanges.map(AppUserModel.fromFirebase);

  @override
  AppUser get currentUser =>
      _isOffline ? (_devUser ?? AppUser.signedOut) : AppUserModel.fromFirebase(_authService.currentUser);

  @override
  Future<AppUser?> getCurrentUser() async {
    if (_isOffline) return _devUser;
    final fb.User? user = _authService.currentUser;
    return AppUserModel.fromFirebase(user);
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    debugPrint('[AUTH-REPO] signInWithEmail: start offline=$_isOffline');
    try {
      final fb.User? user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      debugPrint('[AUTH-REPO] signInWithEmail: firebase signIn done');
      final AppUser appUser = AppUserModel.fromFirebase(user);
      await _persistProfile(appUser);
      return appUser;
    } on AuthException catch (error) {
      debugPrint('[AUTH-REPO] signInWithEmail: AuthException code=${error.code}');
      if (error.code == 'firebase_unavailable' &&
          email.trim().toLowerCase() == _devTestEmail &&
          password == _devTestPassword) {
        return _signInDev(email.trim());
      }
      throw _toDomainError(error);
    } catch (error) {
      debugPrint('[AUTH-REPO] signInWithEmail: error=$error');
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
      final fb.User? user = await _authService.signUpWithEmail(
        name: name,
        email: email,
        password: password,
      );
      final AppUser appUser = AppUserModel.fromFirebase(user);
      await _persistProfile(appUser);
      return appUser;
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final fb.User? user = await _authService.signInWithGoogle();
      final AppUser appUser = AppUserModel.fromFirebase(user);
      await _persistProfile(appUser);
      return appUser;
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } catch (error) {
      throw _toDomainError(error);
    }
  }

  @override
  Future<AppUser?> reloadUser() async {
    try {
      final fb.User? user = await _authService.reloadUser();
      final AppUser appUser = AppUserModel.fromFirebase(user);
      if (appUser.isSignedIn) {
        await _profileRepository.saveProfile(appUser);
      }
      return appUser;
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
  Future<void> signOut() async {
    _devUser = null;
    _devController.add(AppUser.signedOut);
    await _authService.signOut();
  }

  /// Signs in with the hardcoded dev account when Firebase is unavailable so
  /// the full app flow can be exercised offline.
  Future<AppUser> _signInDev(String email) async {
    debugPrint('[AUTH-REPO] dev sign-in: creating user');
    final AppUser user = AppUser(
      id: 'dev-user',
      email: email,
      displayName: 'Test User',
      isEmailVerified: true,
      provider: AuthProvider.email,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    _devUser = user;
    await _persistProfile(user);
    debugPrint('[AUTH-REPO] dev sign-in: profile persisted');
    _devController.add(user);
    debugPrint('[AUTH-REPO] dev sign-in: emitted to stream');
    return user;
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
