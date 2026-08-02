import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/errors/app_exception.dart';
import 'package:nexfit/data/repositories/auth_repository_impl.dart';
import 'package:nexfit/data/services/auth/auth_service.dart';
import 'package:nexfit/data/services/auth/google_sign_in_service.dart';
import 'package:nexfit/data/services/firebase_service.dart';
import 'package:nexfit/data/services/storage/secure_storage_service.dart';
import 'package:nexfit/domain/entities/app_user.dart';
import 'package:nexfit/domain/repositories/auth_repository.dart';
import 'package:nexfit/domain/repositories/user_profile_repository.dart';

/// AuthService whose Firebase-backed methods always fail because Firebase is
/// not configured, which is exactly what happens in offline-first mode.
class _OfflineAuthService extends AuthService {
  _OfflineAuthService({
    required super.firebaseService,
    required super.googleSignInService,
  });

  @override
  Future<fb.User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw const AuthException('authUnavailable', code: 'firebase_unavailable');
  }

  @override
  Future<fb.User?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    throw const AuthException('authUnavailable', code: 'firebase_unavailable');
  }

  @override
  Future<fb.User?> signInWithGoogle() async {
    throw const AuthException('authUnavailable', code: 'firebase_unavailable');
  }
}

class _MemoryProfileRepository implements UserProfileRepository {
  final Map<String, AppUser> users = <String, AppUser>{};

  @override
  Future<void> saveProfile(AppUser user) async {
    users[user.id] = user;
  }

  @override
  Future<AppUser?> getProfile(String uid) async => users[uid];

  @override
  Future<void> updateLastLogin(String uid) async {}

  @override
  Future<void> deleteProfile(String uid) async {
    users.remove(uid);
  }
}

class _MemorySecureStorage extends SecureStorageService {
  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }

  @override
  Future<bool> contains(String key) async => store.containsKey(key);

  @override
  Future<void> deleteAll() async {
    store.clear();
  }
}

void main() {
  late _MemorySecureStorage storage;
  late AuthRepository repository;

  AuthRepository buildRepository() {
    final FirebaseService firebase = FirebaseService();
    final _OfflineAuthService service = _OfflineAuthService(
      firebaseService: firebase,
      googleSignInService: GoogleSignInService(),
    );
    return AuthRepositoryImpl(service, _MemoryProfileRepository(), storage);
  }

  setUp(() {
    storage = _MemorySecureStorage();
    repository = buildRepository();
  });

  test('sign-up offline creates a verified local account', () async {
    final AppUser user = await repository.signUpWithEmail(
      name: 'Rahim',
      email: 'rahim@example.com',
      password: 'secret123',
    );

    expect(user.isSignedIn, isTrue);
    expect(user.displayName, 'Rahim');
    expect(user.email, 'rahim@example.com');
    expect(user.isEmailVerified, isTrue);
    expect(user.provider, AuthProvider.email);
    expect(repository.currentUser.isSignedIn, isTrue);
  });

  test('sign-in offline succeeds with the same credentials', () async {
    await repository.signUpWithEmail(
      name: 'Rahim',
      email: 'rahim@example.com',
      password: 'secret123',
    );

    final AuthRepository fresh = buildRepository();
    final AppUser user = await fresh.signInWithEmail(
      email: 'RAHIM@example.com',
      password: 'secret123',
    );

    expect(user.isSignedIn, isTrue);
    expect(user.email, 'rahim@example.com');
    expect(fresh.currentUser.isSignedIn, isTrue);
  });

  test('sign-in offline rejects a wrong password', () async {
    await repository.signUpWithEmail(
      name: 'Rahim',
      email: 'rahim@example.com',
      password: 'secret123',
    );

    expect(
      () => repository.signInWithEmail(
        email: 'rahim@example.com',
        password: 'wrong',
      ),
      throwsA(
        isA<AuthException>()
            .having((AuthException e) => e.code, 'code', 'wrong-password'),
      ),
    );
  });

  test('sign-in offline reports unknown account', () async {
    expect(
      () => repository.signInWithEmail(
        email: 'nobody@example.com',
        password: 'secret123',
      ),
      throwsA(
        isA<AuthException>()
            .having((AuthException e) => e.code, 'code', 'user-not-found'),
      ),
    );
  });

  test('sign-up offline rejects a duplicate email', () async {
    await repository.signUpWithEmail(
      name: 'Rahim',
      email: 'rahim@example.com',
      password: 'secret123',
    );

    expect(
      () => repository.signUpWithEmail(
        name: 'Rahim',
        email: 'rahim@example.com',
        password: 'other123',
      ),
      throwsA(
        isA<AuthException>()
            .having((AuthException e) => e.code, 'code', 'email-already-in-use'),
      ),
    );
  });

  test('hardcoded dev account still signs in offline', () async {
    final AppUser user = await repository.signInWithEmail(
      email: 'test@gmail.com',
      password: '123456',
    );

    expect(user.isSignedIn, isTrue);
    expect(user.displayName, 'Test User');
  });

  test('offline account survives a fresh repository via stored credentials',
      () async {
    await repository.signUpWithEmail(
      name: 'Karim',
      email: 'karim@example.com',
      password: 'pw1234',
    );

    final AuthRepository fresh = buildRepository();
    final AppUser user = await fresh.signInWithEmail(
      email: 'karim@example.com',
      password: 'pw1234',
    );

    expect(user.isSignedIn, isTrue);
    expect(user.displayName, 'Karim');
  });
}
