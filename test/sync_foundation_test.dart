import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/constants/app_constants.dart';
import 'package:nexfit/core/security/uuid_generator.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/security/device_id_service.dart';
import 'package:nexfit/data/services/storage/secure_storage_service.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/data/services/sync/sync_event_payload.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/sync_state.dart';
import 'package:nexfit/domain/repositories/sync_event_repository.dart';
import 'package:nexfit/domain/repositories/sync_state_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory [SyncEventRepository] used for recorder / engine orchestration.
class _MemorySyncEventRepository implements SyncEventRepository {
  final List<SyncEvent> events = <SyncEvent>[];
  int _nextId = 1;

  @override
  Future<int> insert(SyncEvent event) async {
    final SyncEvent copy = event.copyWith(id: _nextId++);
    events.add(copy);
    return copy.id!;
  }

  @override
  Future<void> insertInTransaction(Transaction txn, SyncEvent event) =>
      insert(event);

  @override
  Future<void> update(SyncEvent event) async {
    final int index = events.indexWhere((SyncEvent e) => e.id == event.id);
    if (index >= 0) events[index] = event;
  }

  @override
  Future<void> updateAll(List<SyncEvent> updated) async {
    for (final SyncEvent event in updated) {
      await update(event);
    }
  }

  @override
  Future<List<SyncEvent>> getPendingByUserId(
    String userId, {
    int? limit,
    int? offset,
  }) => getRetryableByUserId(userId, limit: limit, offset: offset);

  @override
  Future<List<SyncEvent>> getNonCompletedByUserId(
    String userId, {
    int limit = 100,
  }) async {
    return events
        .where(
          (SyncEvent e) =>
              e.userId == userId && e.status != SyncStatus.completed,
        )
        .take(limit)
        .toList();
  }

@override
  Future<void> requeueAllByUserId(String userId, {required DateTime at}) async {
    for (int i = 0; i < events.length; i++) {
      final SyncEvent e = events[i];
      if (e.userId == userId && e.status != SyncStatus.completed) {
        events[i] = e.copyWith(
          status: SyncStatus.pending,
          retryCount: 0,
          nextRetryAt: null,
          clearNextRetryAt: true,
          lastError: 'requeued_manually',
        );
      }
    }
  }

  @override
  Future<void> resolvePermanentFailures(
    String userId, {
    required DateTime at,
  }) async {
    for (int i = 0; i < events.length; i++) {
      final SyncEvent e = events[i];
      if (e.userId == userId && e.status == SyncStatus.failedPermanent) {
        events[i] = e.copyWith(
          status: SyncStatus.completed,
          nextRetryAt: null,
          clearNextRetryAt: true,
        );
      }
    }
  }

  @override
  Future<List<SyncEvent>> getRetryableByUserId(
    String userId, {
    int? limit,
    int? offset,
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    return events
        .where(
          (SyncEvent e) =>
              e.userId == userId &&
              (e.status == SyncStatus.pending ||
                  e.status == SyncStatus.failedRetryable) &&
              (e.nextRetryAt == null || !e.nextRetryAt!.isAfter(effectiveNow)),
        )
        .toList();
  }

  @override
  Future<SyncEvent?> findDuplicate(
    String userId,
    String entity,
    String entityId,
    SyncOperation operation,
  ) async => null;

  @override
  Future<Map<String, int>> countByStatus(String userId) async => <String, int>{
        for (final SyncStatus status in SyncStatus.values) status.name: 0,
      };

  @override
  Future<DateTime?> latestSyncedAt(String userId) async => null;

  @override
  Future<void> deleteCompletedOlderThan(String userId, DateTime threshold) async {}

  @override
  Future<void> deleteCompletedOlderThanAll(DateTime threshold) async {}

  @override
  Future<void> markProcessing(int id, {required DateTime at}) async {}

  @override
  Future<void> markSuccess(
    int id, {
    required DateTime at,
    required DateTime syncedAt,
  }) async {}

  @override
  Future<void> markRetryableFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
    required DateTime nextRetryAt,
  }) async {}

  @override
  Future<void> markPermanentFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
  }) async {}

  @override
  Future<List<int>> resetStuckProcessingEvents(
    String userId, {
    required DateTime olderThan,
    required DateTime at,
  }) async => <int>[];

  @override
  Future<int> getPendingCount(String userId) async => 0;

  @override
  Future<int> getFailedCount(String userId) async => 0;
}

/// Scripted transport: records pushed events and serves a change log.
class _ScriptedTransport implements SyncTransport {
  _ScriptedTransport({List<SyncChange>? remoteChanges})
    : remoteChanges = remoteChanges ?? <SyncChange>[];

final List<SyncChange> remoteChanges;
  final List<SyncEvent> pushed = <SyncEvent>[];
  bool ready = true;
  bool failPush = false;
  bool failPull = false;

  @override
  String get name => 'scripted';

  @override
  bool get isReady => ready;

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    if (failPush) throw const SyncTransportException('network_down');
    pushed.add(event);
    return const SyncPushResult(applied: true, serverRowVersion: 1);
  }

  @override
Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    if (failPull) throw const SyncTransportException('network_down');
    final List<SyncChange> due = remoteChanges
        .where((SyncChange c) => c.cursorId > cursor)
        .toList();
    return SyncPullBatch(
      changes: due,
      nextCursor: due.isEmpty
          ? cursor
          : due.last.cursorId,
      hasMore: due.length == limit,
    );
  }
}

/// Secure-storage method-channel fake so `FlutterSecureStorage` works in tests.
const MethodChannel _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

Map<String, String> _secureStore = <String, String>{};

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    _secureStore = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (MethodCall call) async {
      final Map<Object?, Object?> args =
          (call.arguments as Map?) ?? <Object?, Object?>{};
      switch (call.method) {
        case 'read':
          return _secureStore[args['key']];
        case 'write':
          _secureStore[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          _secureStore.remove(args['key']);
          return null;
        case 'containsKey':
          return _secureStore.containsKey(args['key']);
        case 'readAll':
          return _secureStore;
        case 'deleteAll':
          _secureStore = <String, String>{};
          return null;
      }
      return null;
    });
  });

  group('device id (Part 2)', () {
    test('is a UUID v4, generated once and persisted across calls', () async {
      final DeviceIdService service = DeviceIdService(
        storage: SecureStorageService(),
      );
      final String first = await service.getOrCreate();
      expect(first, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      final String second = await service.getOrCreate();
      expect(second, first);
      expect(_secureStore[AppConstants.deviceIdStorageKey], first);
    });

    test('contains no PII or credentials', () async {
      final String id = await DeviceIdService(
        storage: SecureStorageService(),
      ).getOrCreate();
      expect(id.length, 36);
      expect(id.contains('@'), isFalse);
      expect(id.contains('token'), isFalse);
    });
  });

  group('uuid generator', () {
    test('produces unique version-4 uuids', () {
      final Set<String> seen = <String>{};
      for (int i = 0; i < 1000; i++) {
        seen.add(UuidGenerator.v4());
      }
      expect(seen.length, 1000);
    });
  });

  group('payload contract (Part 6)', () {
    test('round-trips the stable envelope', () {
      final SyncEventPayload payload = SyncEventPayload(
        entity: 'weight_log',
        recordId: 'uuid-1',
        operation: SyncOperation.update,
        baseVersion: 3,
        data: <String, Object?>{'weight_kg': 82.5},
      );
      final String encoded = payload.encode();
      final SyncEventPayload? decoded = SyncEventPayload.tryDecode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.entity, 'weight_log');
      expect(decoded.recordId, 'uuid-1');
      expect(decoded.operation, SyncOperation.update);
      expect(decoded.baseVersion, 3);
      expect(decoded.data['weight_kg'], 82.5);
    });

    test('returns null for malformed envelopes', () {
      expect(SyncEventPayload.tryDecode('not json'), isNull);
      expect(SyncEventPayload.tryDecode(null), isNull);
    });
  });

  group('retry scheduler (Part 17)', () {
    test('backoff follows 2/5/15/30/60/120/300 and caps', () {
      final DateTime base = DateTime.utc(2026, 1, 1);
      final List<int> expected = <int>[2, 5, 15, 30, 60, 120, 300];
      for (int i = 0; i < expected.length; i++) {
        final DateTime next = RetryScheduler.nextRetryAt(i, now: base);
        expect(next.difference(base).inSeconds, expected[i]);
      }
      // Beyond the sequence the cap holds at 300s.
      final DateTime cap = RetryScheduler.nextRetryAt(99, now: base);
      expect(cap.difference(base).inSeconds, 300);
    });
  });

  group('outbox data source (Part 4)', () {
    late AppDatabase appDatabase;

    setUp(() async {
      await databaseFactory.deleteDatabase(await _databasePath());
      appDatabase = AppDatabase();
      final Database db = await appDatabase.database;
      await db.insert('users', <String, Object?>{
        'id': 'user-1',
        'name': 'Tester',
        'email': 't@x.com',
        'provider': 'email',
      });
    });

    tearDown(() async {
      await appDatabase.close();
    });

    SyncEvent newEvent() => SyncEvent(
          userId: 'user-1',
          entity: 'weight_log',
          entityId: 'wl-1',
          operation: SyncOperation.update,
          eventUuid: UuidGenerator.v4(),
          deviceId: 'device-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    test('mark lifecycle transitions persist status/backoff columns', () async {
      final SyncEventRepository repo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      final int id = await repo.insert(newEvent());

      await repo.markProcessing(id, at: DateTime.now());
      expect(
        (await repo.getRetryableByUserId('user-1')),
        isEmpty,
        reason: 'processing events are not retryable',
      );

      await repo.markRetryableFailure(
        id,
        lastError: 'network_down',
        retryCount: 1,
        at: DateTime.now(),
        nextRetryAt: DateTime.now().add(const Duration(seconds: 2)),
      );
      expect(
        await repo.getPendingCount('user-1'),
        1,
        reason: 'retryable events count as pending',
      );

      await repo.markSuccess(
        id,
        at: DateTime.now(),
        syncedAt: DateTime.now(),
      );
      expect(await repo.getPendingCount('user-1'), 0);
      expect(await repo.getFailedCount('user-1'), 0);
    });

    test('getRetryableByUserId respects next_retry_at gating', () async {
      final SyncEventRepository repo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      final int id = await repo.insert(newEvent());
      await repo.markRetryableFailure(
        id,
        lastError: 'network_down',
        retryCount: 1,
        at: DateTime.now(),
        nextRetryAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      // Not yet due.
      expect(await repo.getRetryableByUserId('user-1'), isEmpty);
      // Due once the clock passes.
      expect(
        await repo.getRetryableByUserId(
          'user-1',
          now: DateTime.now().add(const Duration(minutes: 6)),
        ),
        hasLength(1),
      );
    });

    test('resetStuckProcessingEvents reclaims stale PROCESSING only', () async {
      final SyncEventRepository repo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      final int stale = await repo.insert(newEvent());
      await repo.markProcessing(
        stale,
        at: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      final int fresh = await repo.insert(newEvent());
      await repo.markProcessing(fresh, at: DateTime.now());

      final List<int> reclaimed = await repo.resetStuckProcessingEvents(
        'user-1',
        olderThan: DateTime.now().subtract(
          AppConstants.syncStuckProcessingTimeout,
        ),
        at: DateTime.now(),
      );
      expect(reclaimed, contains(stale));
      expect(reclaimed, isNot(contains(fresh)));
    });

    test('permanent failures are counted but not retried', () async {
      final SyncEventRepository repo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      final int id = await repo.insert(newEvent());
      await repo.markPermanentFailure(
        id,
        lastError: 'validation_error',
        retryCount: 3,
        at: DateTime.now(),
      );
      expect(await repo.getFailedCount('user-1'), 1);
      expect(await repo.getRetryableByUserId('user-1'), isEmpty);
    });
  });

  group('transactional outbox (Part 5)', () {
    late AppDatabase appDatabase;

    setUp(() async {
      await databaseFactory.deleteDatabase(await _databasePath());
      appDatabase = AppDatabase();
      final Database db = await appDatabase.database;
      await db.insert('users', <String, Object?>{
        'id': 'user-1',
        'name': 'Tester',
        'email': 't@x.com',
        'provider': 'email',
      });
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('mutation and outbox event commit atomically', () async {
      final SyncEventRepository repo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      final db = await appDatabase.database;
      await db.transaction((Transaction txn) async {
        await txn.insert('weight_log', <String, Object?>{
          'user_id': 'user-1',
          'weight_kg': 82.5,
          'logged_at': 1,
          'created_at': 1,
        });
        await repo.insertInTransaction(
          txn,
          _outboxEvent(),
        );
      });
      expect(await repo.getPendingCount('user-1'), 1);
    });

    test('rollback discards both the row and the outbox event', () async {
      final SyncEventRepository repo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      final db = await appDatabase.database;
      try {
        await db.transaction((Transaction txn) async {
          await txn.insert('weight_log', <String, Object?>{
            'user_id': 'user-1',
            'weight_kg': 82.5,
            'logged_at': 1,
            'created_at': 1,
          });
          await repo.insertInTransaction(txn, _outboxEvent());
          throw StateError('boom'); // force rollback
        });
      } on StateError {
        // expected
      }
      expect(await repo.getPendingCount('user-1'), 0);
      final List<Map<String, Object?>> rows = await db.query('weight_log');
      expect(rows, isEmpty);
    });
  });

  group('recorder identity (Parts 3 & 2)', () {
    test('record stamps event uuid and device id once', () async {
      final _MemorySyncEventRepository repo = _MemorySyncEventRepository();
      SyncEventRecorder.configure(
        repository: repo,
        deviceIdProvider: () async => 'device-abc',
        activeUserId: 'user-1',
      );
      await SyncEventRecorder.record(
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.update,
      );
      final SyncEvent event = repo.events.single;
      expect(event.eventUuid, isNotNull);
      expect(event.deviceId, 'device-abc');
    });

    test('record is a no-op when disabled', () async {
      final _MemorySyncEventRepository repo = _MemorySyncEventRepository();
      SyncEventRecorder.configure(
        repository: repo,
        activeUserId: 'user-1',
        enabled: false,
      );
      await SyncEventRecorder.record(
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.update,
      );
      expect(repo.events, isEmpty);
    });
  });

  group('pull + cursor + remote apply (Parts 10-14, 16)', () {
    late AppDatabase appDatabase;
    late SyncEventRepository eventRepo;
    late SyncStateRepository stateRepo;
    late SyncEngine engine;
    late RemoteChangeApplier applier;

    setUp(() async {
      await databaseFactory.deleteDatabase(await _databasePath());
      appDatabase = AppDatabase();
      await appDatabase.database;
      final Database db = await appDatabase.database;
      await db.insert('users', <String, Object?>{
        'id': 'user-1',
        'name': 'Tester',
        'email': 't@x.com',
        'provider': 'email',
      });
      eventRepo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      stateRepo = SyncStateRepositoryImpl(
        SyncStateLocalDataSource(database: appDatabase),
      );
      applier = RemoteChangeApplier(database: appDatabase);
      engine = SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
      );
    });

    tearDown(() async {
      await appDatabase.close();
    });

    SyncChange weightChange(
      int cursorId, {
      String recordId = 'uuid-1',
      SyncOperation operation = SyncOperation.create,
      String cloudTable = 'weight_logs',
    }) => SyncChange(
          cursorId: cursorId,
          cloudTable: cloudTable,
          recordId: recordId,
          operation: operation,
          payload: operation == SyncOperation.delete
              ? const <String, Object?>{}
              : <String, Object?>{
                  'id': recordId,
                  'user_id': 'user-1',
                  'weight_kg': 82.5,
                  'note': 'morning',
                  'logged_at': '2026-01-01T06:00:00Z',
                  'created_at': '2026-01-01T06:00:00Z',
                  'updated_at': '2026-01-01T06:00:00Z',
                  'row_version': 1,
                },
        );

    test('pull applies remote rows and advances the cursor (Part 11)', () async {
      final _ScriptedTransport transport = _ScriptedTransport(
        remoteChanges: <SyncChange>[
          weightChange(5),
          weightChange(6, recordId: 'uuid-2'),
        ],
      );

      final int pulled = await engine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );

      expect(pulled, 2);
      final Database db = await appDatabase.database;
      final List<Map<String, Object?>> rows = await db.query('weight_log');
      expect(rows, hasLength(2));
      expect(rows.first['uuid'], 'uuid-1');
      expect(rows.first['weight_kg'], 82.5);
      // Cursor advanced past the last applied id.
      final SyncState state = (await stateRepo.getByUserId('user-1'))!;
      expect(state.cursor, 6);
      expect(state.initialSyncCompleted, isTrue);
      expect(state.lastSyncAt, isNotNull);
    });

    test('remote apply never enqueues an outbox event (Part 16)', () async {
      final _ScriptedTransport transport = _ScriptedTransport(
        remoteChanges: <SyncChange>[weightChange(5)],
      );
      await engine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );
      expect(await eventRepo.getPendingCount('user-1'), 0);
      expect(await eventRepo.getFailedCount('user-1'), 0);
    });

test('an unsupported table change is skipped so the batch can still apply',
        () async {
      final _ScriptedTransport transport = _ScriptedTransport(
        remoteChanges: <SyncChange>[
          weightChange(5),
          weightChange(6, cloudTable: 'nonsense_table'),
        ],
      );

      final int pulled = await engine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );

      // The unmapped row is skipped, the applicable row still lands and the
      // cursor advances past both ids (a fresh install replaying its whole
      // history must never stall on a single permanently-unapplicable change).
      expect(pulled, 2);
      final Database db = await appDatabase.database;
      final List<Map<String, Object?>> rows = await db.query('weight_log');
      expect(rows, hasLength(1));
      expect(rows.single['uuid'], 'uuid-1');
      final SyncState? state = await stateRepo.getByUserId('user-1');
      expect(state, isNotNull);
      expect(state!.cursor, 6);
    });

    test('an unresolvable child FK is skipped so the batch can still apply',
        () async {
      // Local master catalog seeded with a LOCAL uuid (fresh install before
      // master sync adopts it); the pulled user row references the SERVER uuid.
      final Database db = await appDatabase.database;
      await db.insert('exercise', <String, Object?>{
        'id': 1,
        'uuid': 'local-ex-1',
        'user_id': null,
        'name': 'Push Up',
        'is_custom': 0,
        'created_at': 1767225600000,
        'updated_at': 1767225600000,
        'row_version': 1,
      });
      final _ScriptedTransport transport = _ScriptedTransport(
        remoteChanges: <SyncChange>[
          weightChange(5),
          SyncChange(
            cursorId: 6,
            cloudTable: 'exercise_favorites',
            recordId: 'fav-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'user_id': 'user-1',
              'exercise_id': 'server-ex-1',
              'created_at': '2026-01-01T06:00:00Z',
              'updated_at': '2026-01-01T06:00:00Z',
              'row_version': 1,
            },
          ),
        ],
      );

      final int pulled = await engine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );

      // The unresolvable favorite is skipped, the weight row still lands and
      // the cursor advances past both ids instead of stalling forever.
      expect(pulled, 2);
      final List<Map<String, Object?>> weights = await db.query('weight_log');
      expect(weights, hasLength(1));
      expect(await db.query('exercise_favorite'), isEmpty);
      final SyncState? state = await stateRepo.getByUserId('user-1');
      expect(state, isNotNull);
      expect(state!.cursor, 6);
    });

    test('a pulled profile row self-heals a missing users parent row', () async {
      // Simulate a device whose `users` row was never written (or was lost):
      // `user_profile.user_id` -> `users(id)` has no parent, so a naive apply
      // would abort the batch on the FK and the pull safety-net would silently
      // skip the row forever, leaving the profile blank.
      final Database db = await appDatabase.database;
      await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: const <Object?>['user-1'],
      );

      final _ScriptedTransport transport = _ScriptedTransport(
        remoteChanges: <SyncChange>[
          SyncChange(
            cursorId: 5,
            cloudTable: 'profiles',
            recordId: 'user-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'user-1',
              'user_id': 'user-1',
              'display_name': 'Test User',
              'height_cm': 180.0,
              'weight_kg': 84.0,
              'fitness_goal': 'weightLoss',
              'created_at': '2026-01-01T06:00:00Z',
              'updated_at': '2026-01-01T06:00:00Z',
              'row_version': 33,
            },
          ),
        ],
      );

      final int pulled = await engine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );

      expect(pulled, 1);
      final List<Map<String, Object?>> profiles =
          await db.query('user_profile');
      expect(profiles, hasLength(1));
      expect(profiles.single['height_cm'], 180.0);
      expect(profiles.single['weight_kg'], 84.0);
      expect(profiles.single['fitness_goal'], 'weightLoss');
      // The applier inserted the minimal parent so the FK resolved.
      final List<Map<String, Object?>> users = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: const <Object?>['user-1'],
      );
      expect(users, hasLength(1));
      expect(users.single['name'], 'Test User');
      final SyncState? state = await stateRepo.getByUserId('user-1');
      expect(state, isNotNull);
      expect(state!.cursor, 5);
    });

    test('delete changes soft-delete the local row (tombstone)', () async {
      final _ScriptedTransport create = _ScriptedTransport(
        remoteChanges: <SyncChange>[weightChange(5)],
      );
      await engine.pull(
        userId: 'user-1',
        transport: create,
        applier: applier,
      );

      final _ScriptedTransport del = _ScriptedTransport(
        remoteChanges: <SyncChange>[
          weightChange(7, recordId: 'uuid-1', operation: SyncOperation.delete),
        ],
      );
      await engine.pull(
        userId: 'user-1',
        transport: del,
        applier: applier,
      );

      final Database db = await appDatabase.database;
      final List<Map<String, Object?>> rows = await db.query('weight_log');
      expect(rows, hasLength(1));
      expect(rows.first['deleted_at'], isNotNull);
    });

    test('cursor is scoped per user (Part 12)', () async {
      final _ScriptedTransport transport = _ScriptedTransport(
        remoteChanges: <SyncChange>[weightChange(5)],
      );
      await engine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );
      // A second user has no cursor yet.
      expect(await stateRepo.getByUserId('user-2'), isNull);
    });
  });

  group('engine orchestration (Parts 13, 15)', () {
    late AppDatabase appDatabase;
    late SyncEventRepository eventRepo;
    late SyncStateRepository stateRepo;
    late RemoteChangeApplier applier;

    setUp(() async {
      await databaseFactory.deleteDatabase(await _databasePath());
      appDatabase = AppDatabase();
      await appDatabase.database;
      final Database db = await appDatabase.database;
      await db.insert('users', <String, Object?>{
        'id': 'user-1',
        'name': 'Tester',
        'email': 't@x.com',
        'provider': 'email',
      });
      eventRepo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      stateRepo = SyncStateRepositoryImpl(
        SyncStateLocalDataSource(database: appDatabase),
      );
      applier = RemoteChangeApplier(database: appDatabase);
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('sync() pushes outbox then pulls remote changes', () async {
      final SyncEngine engine = SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
        deviceIdProvider: () async => 'device-1',
      );
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.update,
      );

      final _ScriptedTransport transport = _ScriptedTransport(
        remoteChanges: <SyncChange>[
          SyncChange(
            cursorId: 5,
            cloudTable: 'weight_logs',
            recordId: 'remote-uuid',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'remote-uuid',
              'user_id': 'user-1',
              'weight_kg': 70.0,
              'logged_at': '2026-01-02T06:00:00Z',
              'created_at': '2026-01-02T06:00:00Z',
              'updated_at': '2026-01-02T06:00:00Z',
              'row_version': 1,
            },
          ),
        ],
      );

      final SyncRunResult result = await engine.sync(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );

      expect(result.processed, 1);
      expect(result.succeeded, 1);
      expect(transport.pushed, hasLength(1));
      expect(result.pulled, 1);
      expect(result.hasPulled, isTrue);

      final Database db = await appDatabase.database;
      final List<Map<String, Object?>> rows = await db.query('weight_log');
      // Remote row was pulled and applied even though push "succeeded".
      expect(rows.map((Map<String, Object?> r) => r['uuid']), contains('remote-uuid'));
      final SyncState state = (await stateRepo.getByUserId('user-1'))!;
      expect(state.initialSyncCompleted, isTrue);
    });

    test('sync() reports partial failure when the pull fails (Part 15)', () async {
      final SyncEngine engine = SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
      );
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.update,
      );

final _ScriptedTransport transport = _ScriptedTransport()
        ..ready = true
        ..failPull = true;
      // Force the pull to fail after a successful push.
      transport.remoteChanges.add(
        SyncChange(
          cursorId: 5,
          cloudTable: 'weight_logs',
          recordId: 'wl-1',
          operation: SyncOperation.create,
          payload: <String, Object?>{
            'id': 'wl-1',
            'user_id': 'user-1',
            'weight_kg': 82.5,
            'created_at': '2026-01-01T06:00:00Z',
            'updated_at': '2026-01-01T06:00:00Z',
            'row_version': 1,
          },
        ),
      );

      final SyncRunResult result = await engine.sync(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );

      expect(result.succeeded, 1);
      expect(result.hasPulled, isFalse);
      expect(result.failed, 1);
    });
  });
}

SyncEvent _outboxEvent() => SyncEvent(
      userId: 'user-1',
      entity: 'weight_log',
      entityId: 'wl-1',
      operation: SyncOperation.update,
      eventUuid: UuidGenerator.v4(),
      deviceId: 'device-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );


