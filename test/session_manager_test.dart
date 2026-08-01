import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/constants/app_constants.dart';
import 'package:nexfit/data/services/security/session_manager.dart';
import 'package:nexfit/data/services/storage/secure_storage_service.dart';
import 'package:nexfit/domain/entities/app_session.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/repositories/session_repository.dart';

/// In-memory [SecureStorageService] so the device id persists in-memory.
class _FakeStorage extends SecureStorageService {
  _FakeStorage(this.values);

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<bool> contains(String key) async => values.containsKey(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

/// In-memory [SessionRepository].
class _MemorySessionRepository implements SessionRepository {
  final List<AppSession> sessions = <AppSession>[];

  @override
  Future<int> insert(AppSession session) async {
    sessions.add(session);
    return sessions.length;
  }

  @override
  Future<void> update(AppSession session) async {
    final int index = sessions.indexWhere(
      (AppSession s) => s.userId == session.userId,
    );
    if (index >= 0) sessions[index] = session;
  }

  @override
  Future<AppSession?> getActiveByUserId(String userId) async {
    final List<AppSession> matches = sessions
        .where((AppSession s) => s.userId == userId && s.isActive)
        .toList();
    return matches.isEmpty ? null : matches.last;
  }

  @override
  Future<List<AppSession>> getByUserId(String userId) async =>
      sessions.where((AppSession s) => s.userId == userId).toList();

  @override
  Future<void> deactivateByUserId(String userId) async {
    for (int index = 0; index < sessions.length; index++) {
      if (sessions[index].userId == userId) {
        sessions[index] = sessions[index].copyWith(isActive: false);
      }
    }
  }

  @override
  Future<void> deleteInactiveOlderThan(DateTime threshold) async {
    sessions.removeWhere(
      (AppSession s) => !s.isActive && s.lastActivityAt.isBefore(threshold),
    );
  }
}

void main() {
  late _MemorySessionRepository repository;
  late _FakeStorage storage;
  late Map<String, String> store;
  late SessionManager manager;

  setUp(() {
    store = <String, String>{};
    storage = _FakeStorage(store);
    repository = _MemorySessionRepository();
    manager = SessionManager(repository: repository, storage: storage);
  });

  test('startSession creates an active session and persists the device id',
      () async {
    final AppSession session = await manager.startSession('user-1');

    expect(session.isActive, isTrue);
    expect(session.token.length, 48);
    expect(session.userId, 'user-1');
    expect(store[AppConstants.deviceIdStorageKey], isNotEmpty);
  });

  test('validate returns valid for a fresh session', () async {
    await manager.startSession('user-1');

    final SessionStatus status = await manager.validate('user-1');
    expect(status, SessionStatus.valid);
  });

  test('touch slides the expiry window', () async {
    final AppSession session = await manager.startSession(
      'user-1',
      timeout: const Duration(minutes: 30),
    );
    final DateTime originalExpiry = session.expiresAt;

    // Let the clock advance so touch can be observed sliding the window even
    // when both calls land within the same millisecond.
    await Future<void>.delayed(const Duration(milliseconds: 2));

    await manager.touch(
      'user-1',
      timeout: const Duration(minutes: 30),
    );

    final AppSession? updated = await repository.getActiveByUserId('user-1');
    expect(updated!.expiresAt.isAfter(originalExpiry), isTrue);
  });

  test('an expired session is deactivated and reported expired', () async {
    await manager.startSession(
      'user-1',
      timeout: const Duration(minutes: -1),
    );

    final SessionStatus status = await manager.validate('user-1');
    expect(status, SessionStatus.expired);
    expect(await repository.getActiveByUserId('user-1'), isNull);
  });

  test('a device change deactivates the session', () async {
    await manager.startSession('user-1');

    // Simulate a different install/device: overwrite the persisted device id.
    store[AppConstants.deviceIdStorageKey] = 'different-device';

    final SessionStatus status = await manager.validate('user-1');
    expect(status, SessionStatus.deviceChanged);
    expect(await repository.getActiveByUserId('user-1'), isNull);
  });

  test('endSession performs a secure logout', () async {
    await manager.startSession('user-1');

    await manager.endSession('user-1');

    expect(await repository.getActiveByUserId('user-1'), isNull);
  });

  test('prune removes inactive sessions beyond retention', () async {
    await manager.startSession('user-1');
    await repository.update(
      (await repository.getActiveByUserId('user-1'))!.copyWith(
        isActive: false,
        lastActivityAt: DateTime.now().subtract(
          AppConstants.sessionRetention * 2,
        ),
      ),
    );

    await manager.prune();

    expect(repository.sessions, isEmpty);
  });
}
