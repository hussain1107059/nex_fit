import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/errors/app_exception.dart';
import 'package:nexfit/data/repositories/auth_repository_impl.dart';
import 'package:nexfit/data/services/auth/auth_service.dart';
import 'package:nexfit/data/services/supabase/supabase_service.dart';
import 'package:nexfit/domain/entities/app_user.dart';
import 'package:nexfit/domain/repositories/auth_repository.dart';
import 'package:nexfit/domain/repositories/user_profile_repository.dart';

/// AuthService stub that never touches Supabase. It records the cloud-profile
/// upserts and lets the tests control every auth outcome.
class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(supabaseService: SupabaseService());

  AppUser? _user;
  final List<AppUser> cloudProfiles = <AppUser>[];
  String? lastVerificationEmail;

  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> sendEmailVerification({String? email}) async {
    lastVerificationEmail = email;
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (email.toLowerCase() == 'rahim@example.com' && password == 'secret123') {
      final AppUser user = AppUser(
        id: 'u-1',
        email: 'rahim@example.com',
        displayName: 'Rahim',
        isEmailVerified: true,
        provider: AuthProvider.email,
      );
      _user = user;
      return user;
    }
    throw const AuthException('authWrongPassword', code: 'invalid_credentials');
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    // Email confirmation is required → Supabase issues no session.
    return AppUser.signedOut;
  }

  @override
  Future<void> ensureProfile(AppUser user) async {
    cloudProfiles.add(user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
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

void main() {
  late _FakeAuthService service;
  late _MemoryProfileRepository profiles;
  late AuthRepository repository;

  setUp(() {
    service = _FakeAuthService();
    profiles = _MemoryProfileRepository();
    repository = AuthRepositoryImpl(service, profiles);
  });

  test('sign-in persists the local profile and ensures the cloud profile',
      () async {
    final AppUser user = await repository.signInWithEmail(
      email: 'rahim@example.com',
      password: 'secret123',
    );

    expect(user.isSignedIn, isTrue);
    expect(user.isEmailVerified, isTrue);
    expect(service.cloudProfiles.single.id, 'u-1');
    expect(profiles.users.containsKey('u-1'), isTrue);
    expect(repository.currentUser.isSignedIn, isTrue);
  });

  test('sign-in errors propagate without any offline fallback', () async {
    expect(
      () => repository.signInWithEmail(
        email: 'rahim@example.com',
        password: 'wrong',
      ),
      throwsA(
        isA<AuthException>()
            .having((AuthException e) => e.code, 'code', 'invalid_credentials'),
      ),
    );

    // A failed sign-in must never create or activate a local account.
    expect(profiles.users, isEmpty);
    expect(repository.currentUser.isSignedIn, isFalse);
  });

  test('sign-up awaiting email confirmation returns a signed-out user', () async {
    final AppUser user = await repository.signUpWithEmail(
      name: 'Rahim',
      email: 'rahim@example.com',
      password: 'secret123',
    );

    // No session is issued until the email is confirmed, so the account must
    // never appear authenticated and nothing is persisted yet.
    expect(user.isSignedIn, isFalse);
    expect(profiles.users, isEmpty);
    expect(service.cloudProfiles, isEmpty);
    expect(repository.currentUser.isSignedIn, isFalse);
  });

  test('sign-out clears the in-memory session through the service', () async {
    await repository.signInWithEmail(
      email: 'rahim@example.com',
      password: 'secret123',
    );

    await repository.signOut();

    expect(service.currentUser, isNull);
    expect(repository.currentUser.isSignedIn, isFalse);
  });

  test('sendEmailVerification forwards the requested email', () async {
    await repository.sendEmailVerification(email: 'new@example.com');

    expect(service.lastVerificationEmail, 'new@example.com');
  });
}
