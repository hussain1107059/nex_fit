import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

import 'package:nexfit/core/constants/app_constants.dart';
import 'package:nexfit/core/errors/app_exception.dart';
import 'package:nexfit/core/utils/result.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/sync_conflict_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/datasources/local/user_profile_local_data_source.dart';
import 'package:nexfit/data/repositories/auth_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_conflict_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/auth/auth_service.dart';
import 'package:nexfit/data/services/supabase/supabase_service.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/data/services/sync/sync_table_registry.dart';
import 'package:nexfit/domain/entities/app_user.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/user_profile.dart';
import 'package:nexfit/domain/repositories/auth_repository.dart';
import 'package:nexfit/domain/repositories/sync_event_repository.dart';
import 'package:nexfit/domain/repositories/sync_state_repository.dart';
import 'package:nexfit/domain/repositories/user_profile_repository.dart';
import 'package:nexfit/domain/usecases/auth/update_password_usecase.dart';

/// PROMPT 27 — Profile & Settings finalization.
///
/// Covers the two new capabilities end to end:
///  1. The profile timezone field (migration v18) survives an offline update,
///     uploads through the sync engine and never causes a sync loop when a
///     pulled change is applied back locally.
///  2. The account layer (change password / logout / delete account) forwards
///     to the auth service without touching Supabase, using the same fake
///     service pattern as `auth_repository_offline_test.dart`.
///
/// See `docs/NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §27.

// ---------------------------------------------------------------------------
// Minimal single-user cloud transport (mirrors the security-audit transport)
// ---------------------------------------------------------------------------

class _CloudRow {
  _CloudRow(this.data, this.version);
  final Map<String, Object?> data;
  int version;
}

class _Change {
  _Change({
    required this.id,
    required this.userId,
    required this.table,
    required this.recordId,
    required this.operation,
    required this.payload,
  });

  final int id;
  final String userId;
  final String table;
  final String recordId;
  final String operation;
  final Map<String, Object?> payload;
}

class _FakeCloud {
  final Map<String, Map<String, _CloudRow>> _rows =
      <String, Map<String, _CloudRow>>{};
  final List<_Change> _changes = <_Change>[];
  int _nextId = 1;
  int inserts = 0;

  Map<String, _CloudRow> rowsFor(String table) =>
      _rows[table] ?? const <String, _CloudRow>{};

  int get changeCount => _changes.length;

  List<_Change> changesFor(
    String userId, {
    required int cursor,
    int limit = 100,
  }) {
    return _changes
        .where((_Change c) => c.userId == userId && c.id > cursor)
        .take(limit)
        .toList();
  }

  void put(String table, String recordId, _CloudRow row) {
    _rows.putIfAbsent(table, () => <String, _CloudRow>{})[recordId] = row;
  }

  void append({
    required String userId,
    required String table,
    required String recordId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    _changes.add(
      _Change(
        id: _nextId++,
        userId: userId,
        table: table,
        recordId: recordId,
        operation: operation,
        payload: Map<String, Object?>.of(payload),
      ),
    );
  }
}

class _FakeTransport implements SyncTransport {
  _FakeTransport({required this.store, required this.database});

  final _FakeCloud store;
  final AppDatabase database;
  int pushCalls = 0;

  @override
  String get name => 'fake-cloud';

  @override
  bool get isReady => true;

  Future<Map<String, Object?>?> _readLocalRow(
    SyncTableMapping mapping,
    SyncEvent event,
  ) async {
    final Database db = await database.database;
    final List<Map<String, Object?>> rows = await db.query(
      mapping.localTable,
      where: '${mapping.localKeyColumn} = ?',
      whereArgs: <Object?>[
        mapping.localKeyColumn == 'user_id' ? event.userId : event.entityId,
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : Map<String, Object?>.from(rows.first);
  }

  Map<String, Object?> _cloudRow(
    SyncTableMapping mapping,
    Map<String, Object?> localRow,
  ) {
    final Map<String, Object?> cloud = <String, Object?>{
      'id': localRow['uuid'] as String,
      'user_id': (localRow['user_id'] as String?) ?? '',
      'row_version': (localRow['row_version'] as num?)?.toInt() ?? 0,
    };
    for (final MapEntry<String, String> entry in mapping.localToCloud.entries) {
      cloud[entry.value] = localRow[entry.key];
    }
    return cloud;
  }

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    pushCalls++;
    final SyncTableMapping? mapping = SyncTableRegistry.byLocalTable(
      event.entity,
    );
    if (mapping == null) {
      return const SyncPushResult(applied: false, lastError: 'unsupported');
    }
    final Map<String, Object?>? localRow = await _readLocalRow(mapping, event);
    final Map<String, Object?> cloud = localRow == null
        ? <String, Object?>{
            'id': event.entityId,
            'user_id': event.userId,
            'row_version': 0,
          }
        : _cloudRow(mapping, localRow);

    switch (event.operation) {
      case SyncOperation.create:
      case SyncOperation.update:
        final _CloudRow? existing =
            store.rowsFor(mapping.cloudTable)[cloud['id'] as String];
        final int version = (existing?.version ?? 0) + 1;
        cloud['row_version'] = version;
        store.put(
          mapping.cloudTable,
          cloud['id'] as String,
          _CloudRow(cloud, version),
        );
        if (existing == null) store.inserts++;
        store.append(
          userId: event.userId,
          table: mapping.cloudTable,
          recordId: cloud['id'] as String,
          operation: existing == null ? 'INSERT' : 'UPDATE',
          payload: cloud,
        );
        return SyncPushResult(applied: true, serverRowVersion: version);
      case SyncOperation.delete:
        return const SyncPushResult(applied: true);
    }
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    final List<_Change> changes = store.changesFor(
      userId,
      cursor: cursor,
      limit: limit,
    );
    final List<SyncChange> result = <SyncChange>[
      for (final _Change change in changes)
        SyncChange(
          cursorId: change.id,
          cloudTable: change.table,
          recordId: change.recordId,
          operation: change.operation == 'DELETE'
              ? SyncOperation.delete
              : change.operation == 'INSERT'
                  ? SyncOperation.create
                  : SyncOperation.update,
          payload: Map<String, Object?>.of(change.payload),
        ),
    ];
    return SyncPullBatch(
      changes: result,
      nextCursor: result.isEmpty ? cursor : result.last.cursorId,
      hasMore: result.length == limit,
    );
  }
}

/// A transport whose push always fails, so the engine exercises the offline
/// queue path (change stays pending until connectivity returns).
class _OfflineTransport implements SyncTransport {
  @override
  String get name => 'offline';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    throw const SyncTransportException('network_unreachable');
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    throw const SyncTransportException('network_unreachable');
  }
}

// ---------------------------------------------------------------------------
// Fake AuthService (never touches Supabase)
// ---------------------------------------------------------------------------

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(supabaseService: SupabaseService());

  AppUser? _user;
  final List<AppUser> cloudProfiles = <AppUser>[];
  String? lastChangedPassword;
  bool deleteAccountCalled = false;
  int signOutCount = 0;

  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();

  @override
  AppUser? get currentUser => _user;

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
    return AppUser.signedOut;
  }

  @override
  Future<void> ensureProfile(AppUser user) async {
    cloudProfiles.add(user);
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    _user = null;
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    if (newPassword == 'weak') {
      throw const AuthException(
        'accountChangePasswordShort',
        code: 'weak_password',
      );
    }
    lastChangedPassword = newPassword;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalled = true;
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

// ---------------------------------------------------------------------------
// Test device (real SQLite via ffi)
// ---------------------------------------------------------------------------

class _Device {
  _Device(this.name);

  final String name;
  late AppDatabase db;
  late Database raw;
  late SyncEventRepository eventRepo;
  late SyncStateRepository stateRepo;

  Future<void> init() async {
    await databaseFactory.deleteDatabase(
      path.join(await databaseFactory.getDatabasesPath(), '$name.db'),
    );
    db = AppDatabase(databaseName: '$name.db');
    raw = await db.database;
    await raw.insert('users', <String, Object?>{
      'id': 'u-1',
      'name': 'Rahim',
      'email': 'rahim@example.com',
      'provider': 'email',
    });
    eventRepo = SyncEventRepositoryImpl(
      SyncEventLocalDataSource(database: db),
    );
    stateRepo = SyncStateRepositoryImpl(
      SyncStateLocalDataSource(database: db),
    );
  }

  SyncEngine engine() => SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
        conflictRepository: SyncConflictRepositoryImpl(
          SyncConflictLocalDataSource(database: db),
        ),
        database: db,
        deviceIdProvider: () async => 'device-$name',
      );

  Future<void> close() => db.close();
}

Future<void> _makeDue(_Device device) async {
  for (final SyncEvent event
      in await device.eventRepo.getRetryableByUserId(
    'u-1',
    now: DateTime.now().add(const Duration(days: 30)),
  )) {
    await device.eventRepo.update(event.copyWith(clearNextRetryAt: true));
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Logger.root.level = Level.OFF;

  late _Device device;

  setUp(() async {
    device = _Device('p27');
    await device.init();
    SyncEventRecorder.configure(
      repository: device.eventRepo,
      deviceIdProvider: () async => 'device-p27',
      activeUserId: 'u-1',
    );
  });

  tearDown(() async {
    SyncEventRecorder.setEnabled(false);
    SyncEventRecorder.setActiveUser(null);
    await device.close();
  });

  group('profile timezone (offline-first + sync)', () {
    test('1. saving a profile persists and round-trips the timezone (v18)',
        () async {
      final UserProfileLocalDataSource dataSource =
          UserProfileLocalDataSource(database: device.db);

      await dataSource.upsert(
        UserProfile(
          userId: 'u-1',
          heightCm: 178,
          weightKg: 82,
          targetCalories: 2400,
          timezone: 'UTC+06:00',
          updatedAt: DateTime.now(),
        ),
      );

      final UserProfile? reloaded = await dataSource.getById('u-1');
      expect(reloaded, isNotNull);
      expect(reloaded!.timezone, 'UTC+06:00');
      expect(reloaded.heightCm, 178);
    });

    test('2. schema version is 18 and the timezone column exists', () async {
      expect(AppConstants.databaseVersion, 18);
      final List<Map<String, Object?>> columns = await device.raw.rawQuery(
        'PRAGMA table_info(user_profile)',
      );
      final Set<String> names = columns
          .map((Map<String, Object?> c) => c['name'] as String)
          .toSet();
      expect(names, contains('timezone'));
    });

    test('3. the user_profile sync mapping carries timezone and never '
        'carries auth credentials', () async {
      final SyncTableMapping mapping = SyncTableRegistry.byLocalTable(
        'user_profile',
      )!;
      expect(mapping.localToCloud['timezone'], 'timezone');
      expect(mapping.localToCloud.containsKey('email'), isFalse);
      expect(mapping.localToCloud.containsKey('password'), isFalse);
    });

    test('4. an offline profile update stays queued and uploads the timezone '
        'once connectivity returns', () async {
      final UserProfileLocalDataSource dataSource =
          UserProfileLocalDataSource(database: device.db);
      await dataSource.upsert(
        UserProfile(
          userId: 'u-1',
          heightCm: 178,
          weightKg: 82,
          timezone: 'UTC+06:00',
          updatedAt: DateTime.now(),
        ),
      );

      final SyncEngine engine = device.engine();
      final SyncRunResult offlineRun = await engine.processQueue(
        'u-1',
        transport: _OfflineTransport(),
      );
      expect(offlineRun.succeeded, 0);
      expect(offlineRun.failed, greaterThan(0));

      final SyncQueueSnapshot stuck = await engine.snapshot('u-1');
      expect(stuck.pending, greaterThan(0),
          reason: 'the profile change must survive the offline push');

      final _FakeCloud store = _FakeCloud();
      await _makeDue(device);
      await engine.sync(
        userId: 'u-1',
        transport: _FakeTransport(store: store, database: device.db),
        applier: RemoteChangeApplier(database: device.db),
      );

      final Map<String, _CloudRow> cloudProfiles = store.rowsFor('profiles');
      expect(cloudProfiles, isNotEmpty);
      expect(cloudProfiles['u-1']!.data['timezone'], 'UTC+06:00');

      final SyncQueueSnapshot finalSnapshot = await engine.snapshot('u-1');
      expect(finalSnapshot.pending, 0,
          reason: 'after the successful push nothing stays queued');
    });

    test('5. applying a pulled profile change locally never creates a new '
        'outbound event (no sync loop)', () async {
      final UserProfileLocalDataSource dataSource =
          UserProfileLocalDataSource(database: device.db);
      await dataSource.upsert(
        UserProfile(
          userId: 'u-1',
          heightCm: 178,
          timezone: 'UTC+06:00',
          updatedAt: DateTime.now(),
        ),
      );

      final _FakeCloud store = _FakeCloud();
      final _FakeTransport transport = _FakeTransport(
        store: store,
        database: device.db,
      );
      final SyncEngine engine = device.engine();

      await engine.sync(
        userId: 'u-1',
        transport: transport,
        applier: RemoteChangeApplier(database: device.db),
      );

      expect(store.rowsFor('profiles')['u-1']!.data['timezone'], 'UTC+06:00');
      expect(store.changeCount, 1,
          reason: 'one INSERT change is recorded for the profile');

      SyncQueueSnapshot after = await engine.snapshot('u-1');
      expect(after.pending, 0);

      // Pulling the very same change back and applying it must not re-queue
      // an update event for the profile row.
      final SyncRunResult secondRun = await engine.sync(
        userId: 'u-1',
        transport: transport,
        applier: RemoteChangeApplier(database: device.db),
      );
      expect(secondRun.failed, 0);
      expect(transport.pushCalls, 1,
          reason: 'the pulled change must not be pushed back');

      after = await engine.snapshot('u-1');
      expect(after.pending, 0,
          reason: 'a round-trip must not create a sync loop');

      final UserProfile? local = await dataSource.getById('u-1');
      expect(local!.timezone, 'UTC+06:00');
      expect(local.updatedAt, isNotNull);
    });
  });

  group('account layer (change password / logout / delete account)', () {
    late _FakeAuthService service;
    late _MemoryProfileRepository profiles;
    late AuthRepository repository;

    setUp(() {
      service = _FakeAuthService();
      profiles = _MemoryProfileRepository();
      repository = AuthRepositoryImpl(service, profiles);
    });

    test('6. change password forwards the new password and succeeds', () async {
      await repository.signInWithEmail(
        email: 'rahim@example.com',
        password: 'secret123',
      );

      await repository.updatePassword(newPassword: 'newpass123');

      expect(service.lastChangedPassword, 'newpass123');
      expect(repository.currentUser.isSignedIn, isTrue);
    });

    test('7. a rejected password surfaces as a friendly AuthException', () async {
      await repository.signInWithEmail(
        email: 'rahim@example.com',
        password: 'secret123',
      );

      expect(
        () => repository.updatePassword(newPassword: 'weak'),
        throwsA(
          isA<AuthException>()
              .having(
                (AuthException e) => e.code,
                'code',
                'weak_password',
              )
              .having(
                (AuthException e) => e.message,
                'message',
                'accountChangePasswordShort',
              ),
        ),
      );
      expect(service.lastChangedPassword, isNull);
    });

    test('8. the updatePassword usecase maps failures to a Result failure',
        () async {
      final UpdatePasswordUsecase usecase = UpdatePasswordUsecase(repository);
      await repository.signInWithEmail(
        email: 'rahim@example.com',
        password: 'secret123',
      );

      final Result<void> ok = await usecase(newPassword: 'fresh123');
      expect(ok.isSuccess, isTrue);

      final Result<void> rejected = await usecase(newPassword: 'weak');
      expect(rejected.isFailure, isTrue);
      expect(rejected.failureOrNull!.message, isNotEmpty);
    });

    test('9. logout clears the session and a fresh sign-in restores it',
        () async {
      await repository.signInWithEmail(
        email: 'rahim@example.com',
        password: 'secret123',
      );
      expect(repository.currentUser.isSignedIn, isTrue);

      await repository.signOut();
      expect(service.signOutCount, 1);
      expect(repository.currentUser.isSignedIn, isFalse);

      final AppUser again = await repository.signInWithEmail(
        email: 'rahim@example.com',
        password: 'secret123',
      );
      expect(again.isSignedIn, isTrue);
      expect(repository.currentUser.id, 'u-1');
    });

    test('10. delete account invokes the service and leaves the user '
        'signed out', () async {
      await repository.signInWithEmail(
        email: 'rahim@example.com',
        password: 'secret123',
      );

      await repository.deleteAccount();

      expect(service.deleteAccountCalled, isTrue);
      expect(repository.currentUser.isSignedIn, isFalse);
      expect(service.currentUser, isNull);
    });
  });
}
