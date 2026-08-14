import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/sync_conflict_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_conflict_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_conflict_record.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/repositories/sync_conflict_repository.dart';
import 'package:nexfit/domain/repositories/sync_event_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 19 - conflict detection and resolution.
///
/// A push that fails the optimistic-lock check (remote `row_version` moved past
/// the event's `base_version`) must:
///  - never silently overwrite the server row (SERVER_WINS default),
///  - never discard the conflicting local data (both sides are snapshotted into
///    the durable `sync_conflict` store),
///  - resolve latestWins events to completed (pull converges locally) and keep
///    manualMerge events pending (`manual_merge_required`),
///  - collapse repeated conflicts on the same unresolved (user, entity, record)
///    into one pending record, and start a fresh record after resolution,
///  - expose a clean per-user pending-conflict count for the UI.
///
/// Scenarios covered: same record edited on two devices, stale base version,
/// server newer, local newer (still server-wins), delete vs update, repeated
/// conflict, resolved conflict, plus the v17 migration and store semantics.

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

/// Transport that reports an optimistic-lock conflict and hands back the
/// current server row snapshot (like the production Supabase transport).
class _ServerConflictTransport implements SyncTransport {
  _ServerConflictTransport({
    this.serverRowVersion = 6,
    this.serverData,
    this.serverUpdatedAt,
  });

  final int serverRowVersion;
  final Map<String, Object?>? serverData;
  final DateTime? serverUpdatedAt;

  @override
  String get name => 'server-conflict';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async => SyncPushResult(
        applied: false,
        conflict: true,
        serverRowVersion: serverRowVersion,
        serverData: serverData,
        serverUpdatedAt: serverUpdatedAt,
      );

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async =>
      const SyncPullBatch(
        changes: <SyncChange>[],
        nextCursor: 0,
        hasMore: false,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late Database db;
  late SyncEventRepository eventRepo;
  late SyncConflictRepository conflictRepo;

  Future<void> setUpDb() async {
    await databaseFactory.deleteDatabase(await _databasePath());
    appDatabase = AppDatabase();
    db = await appDatabase.database;
    await db.insert('users', <String, Object?>{
      'id': 'user-1',
      'name': 'Alice',
      'email': 'alice@x.com',
      'provider': 'email',
    });
    eventRepo = SyncEventRepositoryImpl(
      SyncEventLocalDataSource(database: appDatabase),
    );
    conflictRepo = SyncConflictRepositoryImpl(
      SyncConflictLocalDataSource(database: appDatabase),
    );
  }

  tearDown(() async {
    await appDatabase.close();
  });

  SyncEngine engine() => SyncEngine(
        repository: eventRepo,
        syncStateRepository: SyncStateRepositoryImpl(
          SyncStateLocalDataSource(database: appDatabase),
        ),
        conflictRepository: conflictRepo,
        database: appDatabase,
        deviceIdProvider: () async => 'device-1',
      );

  /// A locally edited `weight_log` row (uuid-based). [rowVersion] is the local
  /// row_version AFTER the edit; [baseVersion] is what the edit was based on.
  Future<void> seedWeightLog({
    int id = 1,
    String uuid = 'wl-uuid-1',
    double weightKg = 82.5,
    int rowVersion = 6,
    DateTime? updatedAt,
    bool deleted = false,
  }) async {
    final DateTime updated = updatedAt ?? DateTime.utc(2026, 1, 5, 7);
    await db.insert('weight_log', <String, Object?>{
      'id': id,
      'uuid': uuid,
      'user_id': 'user-1',
      'weight_kg': weightKg,
      'logged_at': DateTime.utc(2026, 1, 5, 6).millisecondsSinceEpoch,
      'created_at': DateTime.utc(2026, 1, 5).millisecondsSinceEpoch,
      'updated_at': updated.millisecondsSinceEpoch,
      'deleted_at': deleted ? DateTime.utc(2026, 1, 5, 8).millisecondsSinceEpoch : null,
      'row_version': rowVersion,
    });
  }

  Future<SyncEvent> track(
    SyncEngine syncEngine, {
    int baseVersion = 5,
    SyncOperation operation = SyncOperation.update,
    SyncConflictStrategy strategy = SyncConflictStrategy.latestWins,
  }) async {
    final SyncEvent event = SyncEvent(
      userId: 'user-1',
      entity: 'weight_log',
      entityId: '1',
      operation: operation,
      payload: '{"weight_kg":83}',
      eventUuid: 'event-${DateTime.now().microsecondsSinceEpoch}',
      deviceId: 'device-1',
      baseVersion: baseVersion,
      status: SyncStatus.pending,
      conflictStrategy: strategy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await eventRepo.insert(event);
    return event;
  }

  group('v17 migration: sync_conflict store', () {
    setUp(setUpDb);

    test('creates the table, partial unique index and status index', () async {
      final List<Map<String, Object?>> table = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='sync_conflict'",
      );
      expect(table, hasLength(1));

      final List<Map<String, Object?>> pendingIndex = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type='index' "
        "AND name='idx_sync_conflict_pending'",
      );
      expect(pendingIndex.single['sql'], contains("WHERE status = 'pending'"));

      final List<Map<String, Object?>> statusIndex = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_sync_conflict_user_status'",
      );
      expect(statusIndex, hasLength(1));
    });

    test('stores one pending record per (user, entity, record_uuid)', () async {
      final SyncConflictRecord record = SyncConflictRecord(
        userId: 'user-1',
        entity: 'weight_log',
        recordUuid: 'wl-uuid-1',
        localData: '{"kg":83}',
        serverData: '{"kg":84}',
        localVersion: 6,
        serverVersion: 6,
        detectedAt: DateTime.utc(2026, 1, 5),
      );
      await conflictRepo.record(record);
      await conflictRepo.record(
        SyncConflictRecord(
          userId: 'user-1',
          entity: 'weight_log',
          recordUuid: 'wl-uuid-1',
          localData: '{"kg":83}',
          serverData: '{"kg":84}',
          localVersion: 6,
          serverVersion: 7,
          detectedAt: DateTime.utc(2026, 1, 5),
        ),
      );

      expect(await conflictRepo.countPending('user-1'), 1);
      final List<SyncConflictRecord> pending =
          await conflictRepo.getPending('user-1');
      expect(pending.single.serverVersion, 7);
      expect(pending.single.status, ConflictResolutionStatus.pending);
    });
  });

  group('engine: conflict detection and resolution (PROMPT 19)', () {
    setUp(setUpDb);

    test(
      'same record edited on two devices -> durable record, SERVER_WINS, '
      'local data preserved',
      () async {
        await seedWeightLog(weightKg: 82.5, rowVersion: 6);
        final SyncEngine syncEngine = engine();
        await track(syncEngine, baseVersion: 5);

        final DateTime serverUpdatedAt = DateTime.utc(2026, 1, 5, 9);
        final SyncRunResult result = await syncEngine.processQueue(
          'user-1',
          transport: _ServerConflictTransport(
            serverRowVersion: 6,
            serverData: <String, Object?>{
              'id': 'wl-uuid-1',
              'user_id': 'user-1',
              'weight_kg': 84.0,
              'row_version': 6,
              'updated_at': serverUpdatedAt.toIso8601String(),
            },
            serverUpdatedAt: serverUpdatedAt,
          ),
        );

        expect(result.failed, 0);
        expect(result.succeeded, 0);
        expect(result.conflicts, 1);
        expect(
          (await eventRepo.countByStatus('user-1'))[SyncStatus.completed.name],
          1,
          reason: 'SERVER_WINS resolves the event; pull converges locally',
        );

        // A server-won record is kept as history (not pending) so the UI only
        // flags manual-merge conflicts for user action.
        expect(await conflictRepo.countPending('user-1'), 0);
        final List<SyncConflictRecord> history =
            await conflictRepo.getHistory('user-1');
        expect(history, hasLength(1));
        final SyncConflictRecord record = history.single;
        expect(record.entity, 'weight_log');
        expect(record.recordUuid, 'wl-uuid-1');
        expect(record.status, ConflictResolutionStatus.serverWon);
        expect(record.strategy, SyncConflictStrategy.latestWins);
        expect(record.serverVersion, 6);
        expect(record.localVersion, 6);
        expect(record.serverUpdatedAt!.millisecondsSinceEpoch,
            serverUpdatedAt.millisecondsSinceEpoch);
        // Both sides snapshotted: the local edit is never discarded.
        final Map<String, Object?> local =
            jsonDecode(record.localData!) as Map<String, Object?>;
        final Map<String, Object?> server =
            jsonDecode(record.serverData!) as Map<String, Object?>;
        expect(local['weight_kg'], 82.5);
        expect(server['weight_kg'], 84.0);
      },
    );

    test('stale base_version surfaces a conflict and records server version',
        () async {
      await seedWeightLog(rowVersion: 4);
      final SyncEngine syncEngine = engine();
      await track(syncEngine, baseVersion: 3);

      final SyncRunResult result = await syncEngine.processQueue(
        'user-1',
        transport: _ServerConflictTransport(
          serverRowVersion: 9,
          serverData: <String, Object?>{'id': 'wl-uuid-1', 'row_version': 9},
        ),
      );

      expect(result.conflicts, 1);
      final SyncConflictRecord record =
          (await conflictRepo.getHistory('user-1')).single;
      expect(record.serverVersion, 9);
      expect(record.localVersion, 4);
    });

    test('server updated later wins (server authoritative)', () async {
      await seedWeightLog(
        updatedAt: DateTime.utc(2026, 1, 5, 7),
        rowVersion: 6,
      );
      final SyncEngine syncEngine = engine();
      await track(syncEngine, baseVersion: 5);

      final DateTime serverUpdatedAt = DateTime.utc(2026, 1, 5, 10);
      await syncEngine.processQueue(
        'user-1',
        transport: _ServerConflictTransport(
          serverRowVersion: 6,
          serverData: <String, Object?>{'id': 'wl-uuid-1', 'row_version': 6},
          serverUpdatedAt: serverUpdatedAt,
        ),
      );

      final SyncConflictRecord record =
          (await conflictRepo.getHistory('user-1')).single;
      expect(record.status, ConflictResolutionStatus.serverWon);
      expect(record.serverUpdatedAt!.millisecondsSinceEpoch,
          serverUpdatedAt.millisecondsSinceEpoch);
    });

    test('local newer still defaults to SERVER_WINS and keeps the local data',
        () async {
      await seedWeightLog(
        updatedAt: DateTime.utc(2026, 1, 5, 12),
        rowVersion: 6,
      );
      final SyncEngine syncEngine = engine();
      await track(syncEngine, baseVersion: 5);

      await syncEngine.processQueue(
        'user-1',
        transport: _ServerConflictTransport(
          serverRowVersion: 6,
          serverData: <String, Object?>{'id': 'wl-uuid-1', 'row_version': 6},
          serverUpdatedAt: DateTime.utc(2026, 1, 5, 8),
        ),
      );

      final SyncConflictRecord record =
          (await conflictRepo.getHistory('user-1')).single;
      expect(record.status, ConflictResolutionStatus.serverWon,
          reason: 'SERVER_WINS is the default policy even for newer locals');
      expect(record.localData, contains('82.5'));
    });

    test('delete vs update is detected and recorded (server row wins)',
        () async {
      await seedWeightLog(rowVersion: 6, deleted: true);
      final SyncEngine syncEngine = engine();
      await track(
        syncEngine,
        baseVersion: 5,
        operation: SyncOperation.delete,
      );

      final SyncRunResult result = await syncEngine.processQueue(
        'user-1',
        transport: _ServerConflictTransport(
          serverRowVersion: 6,
          serverData: <String, Object?>{
            'id': 'wl-uuid-1',
            'weight_kg': 90.0,
            'row_version': 6,
          },
        ),
      );

      expect(result.conflicts, 1);
      expect(
        (await eventRepo.countByStatus('user-1'))[SyncStatus.completed.name],
        1,
        reason: 'the stale delete is acknowledged; the pull applies the server '
            'update so the newer server row is not silently deleted',
      );
      final SyncConflictRecord record =
          (await conflictRepo.getHistory('user-1')).single;
      expect(record.status, ConflictResolutionStatus.serverWon);
      final Map<String, Object?> local =
          jsonDecode(record.localData!) as Map<String, Object?>;
      expect(local['deleted_at'], isNotNull);
      final Map<String, Object?> server =
          jsonDecode(record.serverData!) as Map<String, Object?>;
      expect(server['weight_kg'], 90.0);
    });

    test('manualMerge stays pending; repeated conflicts refresh one record',
        () async {
      await seedWeightLog(rowVersion: 6);
      final SyncEngine syncEngine = engine();
      await track(
        syncEngine,
        baseVersion: 5,
        strategy: SyncConflictStrategy.manualMerge,
      );

      await syncEngine.processQueue(
        'user-1',
        transport: _ServerConflictTransport(
          serverRowVersion: 6,
          serverData: <String, Object?>{'id': 'wl-uuid-1', 'row_version': 6},
        ),
      );
      expect(await conflictRepo.countPending('user-1'), 1);
      List<SyncEvent> pending = await eventRepo.getPendingByUserId('user-1');
      expect(pending.single.lastError, 'manual_merge_required');
      expect(pending.single.status, SyncStatus.pending);

      // The manual-merge event is retried after its backoff window (PROMPT 21);
      // simulate the window elapsing, then the same row conflicts again: still
      // one pending record, server snapshot refreshed (never duplicated).
      await eventRepo.update(
        pending.single.copyWith(clearNextRetryAt: true),
      );
      await syncEngine.processQueue(
        'user-1',
        transport: _ServerConflictTransport(
          serverRowVersion: 8,
          serverData: <String, Object?>{'id': 'wl-uuid-1', 'row_version': 8},
        ),
      );
      expect(await conflictRepo.countPending('user-1'), 1);
      final List<SyncConflictRecord> pendingRecords =
          await conflictRepo.getPending('user-1');
      expect(pendingRecords.single.serverVersion, 8);
      expect(await conflictRepo.getHistory('user-1'), hasLength(1));
    });

    test('resolved conflicts close; a new conflict starts a fresh record',
        () async {
      await seedWeightLog(rowVersion: 6);
      final SyncEngine syncEngine = engine();
      await track(
        syncEngine,
        baseVersion: 5,
        strategy: SyncConflictStrategy.manualMerge,
      );

      await syncEngine.processQueue(
        'user-1',
        transport: _ServerConflictTransport(
          serverRowVersion: 6,
          serverData: <String, Object?>{'id': 'wl-uuid-1', 'row_version': 6},
        ),
      );
      final SyncConflictRecord first =
          (await conflictRepo.getPending('user-1')).single;
      await conflictRepo.markResolved(
        first.id!,
        at: DateTime.utc(2026, 1, 6),
      );
      expect(await conflictRepo.countPending('user-1'), 0);

      // The manual-merge event is still pending; after its backoff window
      // elapses the next run conflicts again: a brand new pending record is
      // created after resolution.
      final SyncEvent afterResolve =
          (await eventRepo.getPendingByUserId('user-1')).single;
      await eventRepo.update(afterResolve.copyWith(clearNextRetryAt: true));
      await syncEngine.processQueue(
        'user-1',
        transport: _ServerConflictTransport(
          serverRowVersion: 7,
          serverData: <String, Object?>{'id': 'wl-uuid-1', 'row_version': 7},
        ),
      );
      expect(await conflictRepo.countPending('user-1'), 1);
      final List<SyncConflictRecord> history =
          await conflictRepo.getHistory('user-1');
      expect(history, hasLength(2));
      expect(history.first.status, ConflictResolutionStatus.pending);
      expect(history.last.status, ConflictResolutionStatus.resolved);
      expect(history.last.resolvedAt, isNotNull);
    });

    test('record_uuid falls back to the cloud uuid when the local row exists',
        () async {
      await seedWeightLog(rowVersion: 6);
      final SyncEngine syncEngine = engine();
      await track(syncEngine, baseVersion: 5);

      await syncEngine.processQueue(
        'user-1',
        transport: _ServerConflictTransport(
          serverRowVersion: 6,
          serverData: <String, Object?>{'id': 'wl-uuid-1', 'row_version': 6},
        ),
      );

      final SyncConflictRecord record =
          (await conflictRepo.getHistory('user-1')).single;
      expect(record.recordUuid, 'wl-uuid-1');
    });

    test('uuid stamping on the conflict table is not required (schema check)',
        () async {
      // The durable store keys on (user_id, entity, record_uuid); record_uuid
      // is the cloud uuid captured from the local row. Sanity-check that the
      // engine persists without needing an id on insert.
      await seedWeightLog(rowVersion: 6);
      final SyncEngine syncEngine = engine();
      await track(syncEngine, baseVersion: 5);
      await syncEngine.processQueue(
        'user-1',
        transport: _ServerConflictTransport(
          serverRowVersion: 6,
          serverData: <String, Object?>{'id': 'wl-uuid-1', 'row_version': 6},
        ),
      );
      final List<SyncConflictRecord> history =
          await conflictRepo.getHistory('user-1');
      expect(history.single.id, isNotNull);
    });
  });
}