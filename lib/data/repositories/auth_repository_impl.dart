import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/constants/storage_keys.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/release_logger.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../models/app_user_model.dart';
import '../services/auth/auth_service.dart';
import '../services/storage/secure_storage_service.dart';

/// Dev-only credentials accepted when Firebase is unavailable.
const String _devTestEmail = 'test@gmail.com';
const String _devTestPassword = '123456';

/// Data layer implementation of [AuthRepository].
///
/// When Firebase is not configured the app runs in offline-first mode:
/// email sign-up/ sign-in are served from locally stored accounts so the full
/// app flow can be exercised without a backend.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._authService,
    this._profileRepository,
    this._secureStorage,
  );

  final AuthService _authService;
  final UserProfileRepository _profileRepository;
  final SecureStorageService _secureStorage;

  final StreamController<AppUser?> _devController =
      StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _devUser;

  bool get _isOffline => !_authService.firebaseService.isReady;

  @override
  Stream<AppUser?> get authStateChanges => _isOffline
      ? _devController.stream
      : _authService.authStateChanges.map(AppUserModel.fromFirebase);

  @override
  AppUser get currentUser => _isOffline
      ? (_devUser ?? AppUser.signedOut)
      : AppUserModel.fromFirebase(_authService.currentUser);

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
    devLog('[AUTH-REPO] signInWithEmail: start offline=$_isOffline');
    try {
      final fb.User? user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      devLog('[AUTH-REPO] signInWithEmail: firebase signIn done');
      final AppUser appUser = AppUserModel.fromFirebase(user);
      await _persistProfile(appUser);
      return appUser;
    } on AuthException catch (error) {
      devLog('[AUTH-REPO] signInWithEmail: AuthException code=${error.code}');
      if (error.code == 'firebase_unavailable') {
        final _OfflineAccount? account = await _findOfflineAccount(email);
        if (account != null) {
          if (account.password != password) {
            throw const AuthException('authWrongPassword', code: 'wrong-password');
          }
          return _activateOfflineUser(account.user);
        }
        if (email.trim().toLowerCase() == _devTestEmail &&
            password == _devTestPassword) {
          return _signInDev(email.trim());
        }
        throw const AuthException('authUserNotFound', code: 'user-not-found');
      }
      throw _toDomainError(error);
    } catch (error) {
      devLog('[AUTH-REPO] signInWithEmail: error=$error');
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
    } on AuthException catch (error) {
      devLog('[AUTH-REPO] signUpWithEmail: AuthException code=${error.code}');
      if (error.code == 'firebase_unavailable') {
        return _signUpOffline(name, email, password);
      }
      throw _toDomainError(error);
    } catch (error) {
      devLog('[AUTH-REPO] signUpWithEmail: error=$error');
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

  @override
  Future<void> deleteAccount() async {
    _devUser = null;
    _devController.add(AppUser.signedOut);
    await _authService.deleteAccount();
  }

  /// Creates a local account when Firebase is unavailable so sign-up works in
  /// offline-first mode and the same credentials can be used to sign in later.
  Future<AppUser> _signUpOffline(
    String name,
    String email,
    String password,
  ) async {
    devLog('[AUTH-REPO] offline sign-up: creating local user');
    final List<Map<String, dynamic>> accounts = await _readOfflineAccounts();
    final String normalizedEmail = email.trim().toLowerCase();

    final bool exists = accounts.any(
      (Map<String, dynamic> json) =>
          (json['email'] as String? ?? '').toLowerCase() == normalizedEmail,
    );
    if (exists) {
      throw const AuthException('authEmailInUse', code: 'email-already-in-use');
    }

    final AppUser user = AppUser(
      id: 'offline-${normalizedEmail.hashCode.toRadixString(16)}',
      email: email.trim(),
      displayName: name.trim().isEmpty ? null : name.trim(),
      isEmailVerified: true,
      provider: AuthProvider.email,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    accounts.add(_OfflineAccount(user: user, password: password).toJson());
    await _writeOfflineAccounts(accounts);
    devLog('[AUTH-REPO] offline sign-up: local user persisted');
    return _activateOfflineUser(user);
  }

  /// Signs in with the hardcoded dev account when Firebase is unavailable so
  /// the full app flow can be exercised offline.
  Future<AppUser> _signInDev(String email) async {
    devLog('[AUTH-REPO] dev sign-in: creating user');
    final AppUser user = AppUser(
      id: 'dev-user',
      email: email,
      displayName: 'Test User',
      isEmailVerified: true,
      provider: AuthProvider.email,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    return _activateOfflineUser(user);
  }

  /// Marks [user] as the active offline session, persists the profile and
  /// notifies listeners.
  Future<AppUser> _activateOfflineUser(AppUser user) async {
    devLog('[AUTH-REPO] offline sign-in: activating user ${user.id}');
    _devUser = user;
    await _persistProfile(user);
    _devController.add(user);
    devLog('[AUTH-REPO] offline sign-in: profile persisted and emitted');
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

  Future<_OfflineAccount?> _findOfflineAccount(String email) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final List<Map<String, dynamic>> accounts = await _readOfflineAccounts();
    for (final Map<String, dynamic> json in accounts) {
      final _OfflineAccount? account = _OfflineAccount.fromJson(json);
      if (account != null &&
          (account.user.email ?? '').toLowerCase() == normalizedEmail) {
        return account;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _readOfflineAccounts() async {
    try {
      final String? raw = await _secureStorage.read(StorageKeys.offlineUsers);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.whereType<Map>().cast<Map<String, dynamic>>().toList();
    } catch (error, stackTrace) {
      devLog(
        '[AUTH-REPO] read offline accounts failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeOfflineAccounts(List<Map<String, dynamic>> accounts) async {
    try {
      await _secureStorage.write(StorageKeys.offlineUsers, jsonEncode(accounts));
    } catch (error, stackTrace) {
      // A failed write only means the account cannot be restored after an app
      // restart; the in-memory session still works for this run.
      devLog(
        '[AUTH-REPO] write offline accounts failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Never _toDomainError(Object error) {
    if (error is AppException) throw error;
    throw const AppException('errorUnknown', code: 'unknown');
  }
}

/// A locally stored account used when Firebase is unavailable.
class _OfflineAccount {
  _OfflineAccount({required this.user, required this.password});

  final AppUser user;
  final String password;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': user.id,
      'email': (user.email ?? '').toLowerCase(),
      'password': password,
      'displayName': user.displayName,
      'isEmailVerified': user.isEmailVerified,
      'createdAt': user.createdAt?.toIso8601String(),
    };
  }

  static _OfflineAccount? fromJson(Map<String, dynamic> json) {
    final String id = json['id'] as String? ?? '';
    final String email = json['email'] as String? ?? '';
    if (id.isEmpty || email.isEmpty) return null;
    return _OfflineAccount(
      user: AppUser(
        id: id,
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
        isEmailVerified: json['isEmailVerified'] as bool? ?? true,
        provider: AuthProvider.email,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      ),
      password: json['password'] as String? ?? '',
    );
  }
}
