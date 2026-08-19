import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/sync_conflict_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_conflict_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/data/services/sync/sync_table_registry.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_conflict_record.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/sync_state.dart';
import 'package:nexfit/domain/repositories/sync_conflict_repository.dart';
import 'package:nexfit/domain/repositories/sync_event_repository.dart';
import 'package:nexfit/domain/repositories/sync_state_repository.dart';

/// PROMPT 23 — Two-logical-device sync validation.
///
/// Two devices are modeled as two **separate SQLite databases** sharing one
/// in-memory cloud (a Supabase-like store with `sync_changes` keyset
/// pagination, idempotent upserts and optimistic row_version conflict
/// detection). Scenarios:
///
/// 1. Workout created on device A appears on device B.
/// 2. Workout edited on device B propagates back to device A (optimistic lock).
/// 3. Food logged while device A is offline is retained, uploaded later and
///    reaches device B.
/// 4. Concurrent edit of the same row on A and B -> SERVER_WINS conflict,
///    durable conflict record, B's local row converges to the server row.
/// 5. Delete on device A applies as a soft-delete tombstone on device B.
/// 6. 100 offline records are uploaded exactly once (no duplicates on retry).
/// 7. 1000 remote changes are pulled incrementally with a per-batch cursor.
/// 8. Kill-and-restart: a push that committed then timed out is recovered
///    without ever creating a duplicate cloud row.

final DateTime _farFuture = DateTime.now().add(const Duration(days: 30));

/// A single cloud row snapshot.
class _CloudRow {
  _CloudRow(this.data, this.version);
  final Map<String, Object?> data;
  int version;
}

/// One `sync_changes` entry (the keyset-paginated pull feed).
class _CloudChange {
  _CloudChange({
    required this.id,
    required this.table,
    required this.recordId,
    required this.operation,
    required this.userId,
    required this.payload,
  });

  final int id;
  final String table;
  final String recordId;
  final String operation;
  final String userId;
  final Map<String, Object?> payload;
}

/// The shared cloud store: per-table rows keyed by record uuid plus the
/// ordered change feed. Tracks how many rows were first created vs updated so
/// the "uploaded exactly once" invariant can be asserted across retries.
class _CloudStore {
  final Map<String, Map<String, _CloudRow>> _rows = <String, Map<String, _CloudRow>>{};
  final List<_CloudChange> _changes = <_CloudChange>[];
  int _nextId = 1;
  int inserts = 0;
  int updates = 0;

  _CloudRow? row(String table, String recordId) => _rows[table]?[recordId];

  Map<String, _CloudRow> rowsFor(String table) =>
      _rows[table] ?? const <String, _CloudRow>{};

  int get changeCount => _changes.length;

  void put(String table, String recordId, _CloudRow row) {
    _rows.putIfAbsent(table, () => <String, _CloudRow>{})[recordId] = row;
  }

  void appendChange({
    required String table,
    required String recordId,
    required String operation,
    required String userId,
    required Map<String, Object?> payload,
  }) {
    _changes.add(
      _CloudChange(
        id: _nextId++,
        table: table,
        recordId: recordId,
        operation: operation,
        userId: userId,
        payload: Map<String, Object?>.of(payload),
      ),
    );
  }

  /// Seeds a remote row plus its INSERT change (used to build a cloud that has
  /// "always" had 1000 rows without a local device).
  void seed({
    required String table,
    required String recordId,
    required String userId,
    required Map<String, Object?> payload,
  }) {
    final int version = (payload['row_version'] as num?)?.toInt() ?? 0;
    put(table, recordId, _CloudRow(payload, version));
    appendChange(
      table: table,
      recordId: recordId,
      operation: 'INSERT',
      userId: userId,
      payload: payload,
    );
  }

  List<_CloudChange> changesAfter({
    required String userId,
    required int cursor,
    int limit = 100,
  }) {
    return _changes
        .where((_CloudChange c) => c.userId == userId && c.id > cursor)
        .take(limit)
        .toList();
  }
}

/// A device-facing transport talking to the shared [_CloudStore]. Mirrors the
/// Supabase transport: idempotent upserts keyed on the record uuid, optimistic
/// row_version conditional writes, soft-delete tombstones, and a pull feed of
/// `sync_changes`. `networkDown` models being offline (push throws a retryable
/// transport error, so events are retained in the outbox); `timeoutOnPushOnce`
/// models a push that committed server-side but timed out before ack.
class _CloudStoreTransport implements SyncTransport {
  _CloudStoreTransport({
    required this.store,
    required this.database,
    this.timeoutOnPushOnce = false,
  });

  final _CloudStore store;
  final AppDatabase database;
  bool networkDown = false;
  final bool timeoutOnPushOnce;
  bool _timedOut = false;
  int pushCalls = 0;
  int pullCalls = 0;

  @override
  String get name => 'cloud';

  @override
  bool get isReady => true; // configured; reachability is modeled by throws

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
    if (mapping.cloudHasDeletedAt) {
      final Object? deletedAt = localRow['deleted_at'];
      cloud['deleted_at'] = deletedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((deletedAt as num).toInt())
              .toUtc()
              .toIso8601String();
    }
    for (final MapEntry<String, String> entry in mapping.localToCloud.entries) {
      cloud[entry.value] = _convert(mapping, entry.value, localRow[entry.key]);
    }
    return cloud;
  }

  Object? _convert(
    SyncTableMapping mapping,
    String cloudColumn,
    Object? value,
  ) {
    if (value == null) return null;
    if (mapping.timestampColumns.contains(cloudColumn)) {
      return DateTime.fromMillisecondsSinceEpoch((value as num).toInt())
          .toUtc()
          .toIso8601String();
    }
    if (mapping.dateColumns.contains(cloudColumn)) {
      final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
        (value as num).toInt(),
      );
      return '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    }
    if (mapping.booleanColumns.contains(cloudColumn)) {
      return value == 1;
    }
    return value;
  }

  DateTime? _updatedAt(Map<String, Object?> row) {
    final Object? updated = row['updated_at'];
    if (updated is String) return DateTime.tryParse(updated)?.toUtc();
    return null;
  }

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    pushCalls++;
    final SyncTableMapping? mapping = SyncTableRegistry.byLocalTable(
      event.entity,
    );
    if (mapping == null) {
      return const SyncPushResult(applied: false, lastError: 'unsupported_entity');
    }
    if (networkDown) {
      throw const SyncTransportException('network_unreachable');
    }
    final Map<String, Object?>? localRow = await _readLocalRow(mapping, event);
    switch (event.operation) {
      case SyncOperation.create:
      case SyncOperation.update:
        if (localRow == null) {
          return const SyncPushResult(applied: false, lastError: 'local_row_missing');
        }
        return _write(mapping, event, localRow);
      case SyncOperation.delete:
        return _remove(mapping, event, localRow);
    }
  }

  SyncPushResult _write(
    SyncTableMapping mapping,
    SyncEvent event,
    Map<String, Object?> localRow,
  ) {
    final Map<String, Object?> cloudRow = _cloudRow(mapping, localRow);
    final String recordId = cloudRow['id'] as String;
    final _CloudRow? existing = store.row(mapping.cloudTable, recordId);

    if (event.operation == SyncOperation.create || event.baseVersion == 0) {
      // Idempotent upsert keyed on the record uuid (Part 8).
      final int version = (existing?.version ?? 0) + 1;
      cloudRow['row_version'] = version;
      store.put(
        mapping.cloudTable,
        recordId,
        _CloudRow(cloudRow, version),
      );
      if (existing == null) {
        store.inserts++;
        store.appendChange(
          table: mapping.cloudTable,
          recordId: recordId,
          operation: 'INSERT',
          userId: event.userId,
          payload: cloudRow,
        );
      } else {
        store.updates++;
        store.appendChange(
          table: mapping.cloudTable,
          recordId: recordId,
          operation: 'UPDATE',
          userId: event.userId,
          payload: cloudRow,
        );
      }
      if (timeoutOnPushOnce && !_timedOut) {
        _timedOut = true;
        throw const SyncTransportException('request_timeout');
      }
      return SyncPushResult(applied: true, serverRowVersion: version);
    }

    // Optimistic concurrency check (Part 9): write only when the remote
    // row_version still equals the event's base_version.
    if (existing == null) {
      // Remote row gone (deleted by another device): server wins via pull.
      return const SyncPushResult(applied: false, conflict: true);
    }
    if (existing.version != event.baseVersion) {
      return SyncPushResult(
        applied: false,
        conflict: true,
        serverRowVersion: existing.version,
        serverData: Map<String, Object?>.of(existing.data),
        serverUpdatedAt: _updatedAt(existing.data),
      );
    }
    final int version = existing.version + 1;
    cloudRow['row_version'] = version;
    store.put(mapping.cloudTable, recordId, _CloudRow(cloudRow, version));
    store.updates++;
    store.appendChange(
      table: mapping.cloudTable,
      recordId: recordId,
      operation: 'UPDATE',
      userId: event.userId,
      payload: cloudRow,
    );
    return SyncPushResult(applied: true, serverRowVersion: version);
  }

  SyncPushResult _remove(
    SyncTableMapping mapping,
    SyncEvent event,
    Map<String, Object?>? localRow,
  ) {
    if (mapping.cloudTable == 'profiles') {
      return const SyncPushResult(applied: true);
    }
    final String? recordId = localRow?['uuid'] as String?;
    if (recordId == null) return const SyncPushResult(applied: true);
    final _CloudRow? existing = store.row(mapping.cloudTable, recordId);
    if (existing == null) return const SyncPushResult(applied: true);
    if (existing.version != event.baseVersion) {
      return SyncPushResult(
        applied: false,
        conflict: true,
        serverRowVersion: existing.version,
        serverData: Map<String, Object?>.of(existing.data),
        serverUpdatedAt: _updatedAt(existing.data),
      );
    }
    final int version = existing.version + 1;
    final Map<String, Object?> tombstoned =
        Map<String, Object?>.of(existing.data)
          ..['deleted_at'] = DateTime.now().toUtc().toIso8601String()
          ..['row_version'] = version;
    store.put(mapping.cloudTable, recordId, _CloudRow(tombstoned, version));
    store.appendChange(
      table: mapping.cloudTable,
      recordId: recordId,
      operation: 'DELETE',
      userId: event.userId,
      payload: const <String, Object?>{},
    );
    return SyncPushResult(applied: true, serverRowVersion: version);
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    pullCalls++;
    if (networkDown) {
      throw const SyncTransportException('network_unreachable');
    }
    final List<_CloudChange> changes = store.changesAfter(
      userId: userId,
      cursor: cursor,
      limit: limit,
    );
    final List<SyncChange> result = <SyncChange>[
      for (final _CloudChange change in changes)
        SyncChange(
          cursorId: change.id,
          cloudTable: change.table,
          recordId: change.recordId,
          operation: _operationFrom(change.operation),
          payload: Map<String, Object?>.of(change.payload),
        ),
    ];
    return SyncPullBatch(
      changes: result,
      nextCursor: result.isEmpty ? cursor : result.last.cursorId,
      hasMore: result.length == limit,
    );
  }

  SyncOperation _operationFrom(String value) {
    switch (value) {
      case 'INSERT':
        return SyncOperation.create;
      case 'DELETE':
        return SyncOperation.delete;
      default:
        return SyncOperation.update;
    }
  }
}

/// A logical device: its own SQLite database + the full sync stack, sharing
/// only the cloud store.
class _Device {
  _Device(this.name);

  final String name;
  late AppDatabase db;
  late Database raw;
  late SyncEventRepository eventRepo;
  late SyncStateRepository stateRepo;
  late SyncConflictRepository conflictRepo;
  late RemoteChangeApplier applier;

  Future<void> init() async {
    await databaseFactory.deleteDatabase(
      path.join(await databaseFactory.getDatabasesPath(), '$name.db'),
    );
    db = AppDatabase(databaseName: '$name.db');
    raw = await db.database;
    await raw.insert('users', <String, Object?>{
      'id': 'user-1',
      'name': 'Tester',
      'email': 't@x.com',
      'provider': 'email',
    });
    eventRepo = SyncEventRepositoryImpl(
      SyncEventLocalDataSource(database: db),
    );
    stateRepo = SyncStateRepositoryImpl(
      SyncStateLocalDataSource(database: db),
    );
    conflictRepo = SyncConflictRepositoryImpl(
      SyncConflictLocalDataSource(database: db),
    );
    applier = RemoteChangeApplier(database: db);
  }

  SyncEngine engine() => SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
        conflictRepository: conflictRepo,
        database: db,
        deviceIdProvider: () async => 'device-$name',
      );

  Future<void> close() => db.close();
}

/// Clears the backoff gate on every pending/retryable event so the next run
/// retries them (simulates the wait elapsing).
Future<void> _makeDue(_Device device) async {
  for (final SyncEvent event
      in await device.eventRepo.getRetryableByUserId('user-1', now: _farFuture)) {
    await device.eventRepo.update(event.copyWith(clearNextRetryAt: true));
  }
}

Future<int> _seedWeightLog(
  Database db, {
  required String uuid,
  double weightKg = 80.0,
}) async {
  final int now = DateTime.now().millisecondsSinceEpoch;
  return db.insert('weight_log', <String, Object?>{
    'uuid': uuid,
    'user_id': 'user-1',
    'weight_kg': weightKg,
    'logged_at': now,
    'created_at': now,
    'updated_at': now,
    'row_version': 1,
  });
}

Future<int> _seedWorkout(
  Database db, {
  required String uuid,
  required String name,
}) async {
  final int now = DateTime.now().millisecondsSinceEpoch;
  return db.insert('workout', <String, Object?>{
    'uuid': uuid,
    'user_id': 'user-1',
    'name': name,
    'is_custom': 1,
    'created_at': now,
    'updated_at': now,
    'row_version': 1,
  });
}

Future<int> _seedWorkoutHistory(
  Database db, {
  required String uuid,
  double caloriesBurn = 0,
  bool isCompleted = false,
}) async {
  final int now = DateTime.now().millisecondsSinceEpoch;
  return db.insert('workout_history', <String, Object?>{
    'uuid': uuid,
    'user_id': 'user-1',
    'workout_id': null,
    'started_at': now,
    'ended_at': null,
    'duration_minutes': null,
    'calories_burn': isCompleted ? caloriesBurn : null,
    'is_completed': isCompleted ? 1 : 0,
    'created_at': now,
    'updated_at': now,
    'row_version': 1,
  });
}

Future<int> _seedFoodLog(
  Database db, {
  required String uuid,
  double calories = 350,
}) async {
  final int now = DateTime.now().millisecondsSinceEpoch;
  return db.insert('food_log', <String, Object?>{
    'uuid': uuid,
    'user_id': 'user-1',
    'quantity': 1,
    'calories': calories,
    'logged_at': now,
    'created_at': now,
    'updated_at': now,
    'row_version': 1,
  });
}

/// The local integer `id` for the row with [uuid] on [device] (the outbox
/// `entityId`).
Future<int> _localId(_Device device, String table, String uuid) async {
  final List<Map<String, Object?>> rows = await device.raw.query(
    table,
    columns: const <String>['id'],
    where: 'uuid = ?',
    whereArgs: <Object?>[uuid],
    limit: 1,
  );
  return rows.single['id'] as int;
}

Future<List<Map<String, Object?>>> _rows(
  _Device device,
  String table,
) async =>
    device.raw.query(table);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late _Device deviceA;
  late _Device deviceB;
  late _CloudStore store;

  setUp(() async {
    store = _CloudStore();
    deviceA = _Device('a');
    deviceB = _Device('b');
    await deviceA.init();
    await deviceB.init();
  });

  tearDown(() async {
    await deviceA.close();
    await deviceB.close();
  });

  group('two-logical-device sync', () {
    test('1. workout created on device A appears on device B', () async {
      final int wkId = await _seedWorkout(deviceA.raw, uuid: 'wk-1', name: 'Push Day');
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'workout',
            entityId: '$wkId',
            operation: SyncOperation.create,
          );

      final _CloudStoreTransport transportA =
          _CloudStoreTransport(store: store, database: deviceA.db);
      final SyncRunResult pushed = await deviceA.engine().sync(
            userId: 'user-1',
            transport: transportA,
            applier: deviceA.applier,
          );
      expect(pushed.succeeded, 1);
      expect(store.rowsFor('workouts'), hasLength(1));

      final _CloudStoreTransport transportB =
          _CloudStoreTransport(store: store, database: deviceB.db);
      final SyncRunResult pulled = await deviceB.engine().sync(
            userId: 'user-1',
            transport: transportB,
            applier: deviceB.applier,
          );
      expect(pulled.hasPulled, isTrue);
      final List<Map<String, Object?>> workouts =
          await _rows(deviceB, 'workout');
      expect(workouts, hasLength(1));
      expect(workouts.single['name'], 'Push Day');
      expect(workouts.single['uuid'], 'wk-1');
    });

    test('1b. workout completed on A arrives completed on B (INSERT + '
        'UPDATE applied in one pull batch)', () async {
      // Device A starts a workout session (history row v1, incomplete) and the
      // mid-workout INSERT is pushed first, mirroring the real capture order.
      final int whA = await _seedWorkoutHistory(deviceA.raw, uuid: 'wh-1');
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'workout_history',
            entityId: '$whA',
            operation: SyncOperation.create,
          );
      await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );

      // Device A completes the session: ONE local update bumps to v2 and sets
      // ended_at/duration/calories/is_completed together (mirrors
      // WorkoutSessionRepositoryImpl.completeSession).
      final int end = DateTime.now().millisecondsSinceEpoch + 60000;
      await deviceA.raw.update(
        'workout_history',
        <String, Object?>{
          'ended_at': end,
          'duration_minutes': 1,
          'calories_burn': 4.5,
          'is_completed': 1,
          'updated_at': end,
          'row_version': 2,
        },
        where: 'uuid = ?',
        whereArgs: <Object?>['wh-1'],
      );
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'workout_history',
            entityId: '$whA',
            operation: SyncOperation.update,
            baseVersion: 1,
          );
      await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );

      // Device B pulls the INSERT + UPDATE pair in a single batch.
      await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );

      final List<Map<String, Object?>> rowsB =
          await _rows(deviceB, 'workout_history');
      expect(rowsB, hasLength(1));
      expect(rowsB.single['uuid'], 'wh-1');
      expect(rowsB.single['is_completed'], 1,
          reason: 'the completion UPDATE must overwrite the mid-workout INSERT');
      expect(rowsB.single['calories_burn'], 4.5);
      expect(rowsB.single['row_version'], 2);
    });

    test('2. workout edited on device B propagates back to device A '
        '(optimistic lock)', () async {
      final int wkA = await _seedWorkout(deviceA.raw, uuid: 'wk-1', name: 'Push Day');
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'workout',
            entityId: '$wkA',
            operation: SyncOperation.create,
          );
      await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );
      await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );

      // Device B edits the workout it pulled (local row_version is now 1).
      final int wkB = await _localId(deviceB, 'workout', 'wk-1');
      final int now = DateTime.now().millisecondsSinceEpoch;
      await deviceB.raw.update(
        'workout',
        <String, Object?>{
          'name': 'Push Day v2',
          'updated_at': now,
          'row_version': 2,
        },
        where: 'uuid = ?',
        whereArgs: <Object?>['wk-1'],
      );
      await deviceB.engine().track(
            userId: 'user-1',
            entity: 'workout',
            entityId: '$wkB',
            operation: SyncOperation.update,
            baseVersion: 1,
          );

      final SyncRunResult edited = await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );
      expect(edited.succeeded, 1);
      expect(store.row('workouts', 'wk-1')!.version, 2);

      await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );
      final List<Map<String, Object?>> workoutsA =
          await _rows(deviceA, 'workout');
      expect(workoutsA.single['name'], 'Push Day v2',
          reason: 'B\'s optimistic update converges on A through the pull');
      expect(workoutsA.single['row_version'], 2);
    });

    test('3. food logged while offline is retained, uploaded later and '
        'reaches device B', () async {
      await _seedFoodLog(deviceA.raw, uuid: 'fl-1', calories: 350);
      final int flId =
          await _localId(deviceA, 'food_log', 'fl-1');
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'food_log',
            entityId: '$flId',
            operation: SyncOperation.create,
          );

      // Offline: push throws a retryable network error; the event is retained
      // in the outbox (never dropped).
      final _CloudStoreTransport offline =
          _CloudStoreTransport(store: store, database: deviceA.db)
            ..networkDown = true;
      await deviceA.engine().processQueue('user-1', transport: offline);
      final SyncEvent retained =
          (await deviceA.eventRepo
                  .getRetryableByUserId('user-1', now: _farFuture))
              .single;
      expect(retained.status, SyncStatus.failedRetryable);
      expect(store.rowsFor('food_logs'), isEmpty,
          reason: 'nothing reached the cloud while offline');

      // Back online: the same event uploads exactly once and B sees it.
      await _makeDue(deviceA);
      final SyncRunResult uploaded = await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );
      expect(uploaded.succeeded, 1);
      expect(store.rowsFor('food_logs'), hasLength(1));

      await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );
      final List<Map<String, Object?>> foodLogsB =
          await _rows(deviceB, 'food_log');
      expect(foodLogsB, hasLength(1));
      expect(foodLogsB.single['calories'], 350);
      expect(foodLogsB.single['uuid'], 'fl-1');
    });

    test('4. concurrent edits on A and B: SERVER_WINS conflict, B converges '
        'to the server row and the conflict is recorded', () async {
      final int wlA = await _seedWeightLog(deviceA.raw, uuid: 'wl-1', weightKg: 80.0);
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$wlA',
            operation: SyncOperation.create,
          );
      await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );
      await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );

      // Both devices edit the row concurrently, each based on version 1.
      final int wlB = await _localId(deviceB, 'weight_log', 'wl-1');
      final int now = DateTime.now().millisecondsSinceEpoch;
      await deviceA.raw.update(
        'weight_log',
        <String, Object?>{
          'weight_kg': 81.0,
          'updated_at': now,
          'row_version': 2,
        },
        where: 'uuid = ?',
        whereArgs: <Object?>['wl-1'],
      );
      await deviceB.raw.update(
        'weight_log',
        <String, Object?>{
          'weight_kg': 83.0,
          'updated_at': now,
          'row_version': 2,
        },
        where: 'uuid = ?',
        whereArgs: <Object?>['wl-1'],
      );
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$wlA',
            operation: SyncOperation.update,
            baseVersion: 1,
          );
      await deviceB.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$wlB',
            operation: SyncOperation.update,
            baseVersion: 1,
          );

      // A wins the optimistic lock (cloud version 1 -> 2).
      final SyncRunResult aRun = await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );
      expect(aRun.succeeded, 1);
      expect(store.row('weight_logs', 'wl-1')!.version, 2);

      // B's stale write (baseVersion 1 != cloud 2) conflicts; latestWins is
      // SERVER_WINS so B's event completes and the pull overwrites B's row.
      final SyncRunResult bRun = await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );
      expect(bRun.conflicts, 1);
      final List<Map<String, Object?>> weightB =
          await _rows(deviceB, 'weight_log');
      expect(weightB.single['weight_kg'], 81.0,
          reason: 'the server row wins; B\'s stale 83.0 edit is not silent');
      expect(weightB.single['row_version'], 2);

      final List<SyncConflictRecord> conflicts =
          await deviceB.conflictRepo.getHistory('user-1');
      expect(conflicts, isNotEmpty,
          reason: 'the stale write is captured in the durable conflict store');
      expect(conflicts.first.recordUuid, 'wl-1');
    });

    test('5. delete on device A applies a soft-delete tombstone on device B',
        () async {
      final int wlA = await _seedWeightLog(deviceA.raw, uuid: 'wl-1', weightKg: 80.0);
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$wlA',
            operation: SyncOperation.create,
          );
      await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );
      await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );

      // Device A soft-deletes the row (tombstone) based on version 1.
      final int now = DateTime.now().millisecondsSinceEpoch;
      await deviceA.raw.update(
        'weight_log',
        <String, Object?>{
          'deleted_at': now,
          'updated_at': now,
          'row_version': 2,
        },
        where: 'uuid = ?',
        whereArgs: <Object?>['wl-1'],
      );
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$wlA',
            operation: SyncOperation.delete,
            baseVersion: 1,
          );

      final SyncRunResult deleted = await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );
      expect(deleted.succeeded, 1);
      final _CloudRow? cloud = store.row('weight_logs', 'wl-1');
      expect(cloud, isNotNull);
      expect(cloud!.data['deleted_at'], isNotNull,
          reason: 'the cloud row is tombstoned, not hard-deleted');

      await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );
      final List<Map<String, Object?>> weightB =
          await _rows(deviceB, 'weight_log');
      expect(weightB, hasLength(1),
          reason: 'soft delete keeps the row for re-apply safety');
      expect(weightB.single['deleted_at'], isNotNull,
          reason: 'B applies the tombstone');
    });

    test('6. 100 offline records upload exactly once', () async {
      final _CloudStoreTransport offline =
          _CloudStoreTransport(store: store, database: deviceA.db)
            ..networkDown = true;
      for (int i = 0; i < 100; i++) {
        final String uuid = 'wl-$i';
        final int id = await _seedWeightLog(
          deviceA.raw,
          uuid: uuid,
          weightKg: 60.0 + i,
        );
        await deviceA.engine().track(
              userId: 'user-1',
              entity: 'weight_log',
              entityId: '$id',
              operation: SyncOperation.create,
            );
      }

      // Offline runs: every event is retained as a retryable failure.
      await deviceA.engine().processQueue('user-1', transport: offline);
      final Map<String, int> offlineCounts =
          await deviceA.eventRepo.countByStatus('user-1');
      expect(
        offlineCounts[SyncStatus.failedRetryable.name],
        100,
        reason: 'all 100 offline mutations are durable in the outbox',
      );
      expect(store.rowsFor('weight_logs'), isEmpty);

      await _makeDue(deviceA);
      final SyncRunResult uploaded = await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );
      expect(uploaded.succeeded, 100);
      expect(store.rowsFor('weight_logs'), hasLength(100));
      expect(store.inserts, 100, reason: 'exactly one cloud insert per record');

      // A second sync must not re-upload anything.
      final SyncRunResult second = await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );
      expect(second.processed, 0);
      expect(store.rowsFor('weight_logs'), hasLength(100));
      expect(store.inserts, 100,
          reason: 'no duplicate cloud rows on re-sync');
    });

    test('7. 1000 remote changes are pulled incrementally with a per-batch '
        'cursor', () async {
      for (int i = 1; i <= 1000; i++) {
        store.seed(
          table: 'weight_logs',
          recordId: 'wl-$i',
          userId: 'user-1',
          payload: <String, Object?>{
            'id': 'wl-$i',
            'user_id': 'user-1',
            'row_version': 1,
            'weight_kg': 70.0 + (i % 50),
            'logged_at': '2026-01-01T06:00:00Z',
            'created_at': '2026-01-01T06:00:00Z',
            'updated_at': '2026-01-01T06:00:00Z',
            'deleted_at': null,
          },
        );
      }

      final SyncRunResult first = await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );
      expect(first.pulled, 1000);
      expect(await _rows(deviceB, 'weight_log'), hasLength(1000));
      expect((await deviceB.stateRepo.getByUserId('user-1'))!.cursor, 1000);

      // Incremental: nothing left to pull, cursor is stable.
      final SyncRunResult second = await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );
      expect(second.pulled, 0);
      expect((await deviceB.stateRepo.getByUserId('user-1'))!.cursor, 1000);
    });

    test('8. kill-and-restart: a committed-but-timed-out push is recovered '
        'without creating a duplicate cloud row', () async {
      final int wlId = await _seedWeightLog(deviceA.raw, uuid: 'wl-1', weightKg: 80.0);
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$wlId',
            operation: SyncOperation.create,
          );

      // First push commits server-side, then times out before the ack.
      await deviceA.engine().processQueue(
        'user-1',
        transport: _CloudStoreTransport(
          store: store,
          database: deviceA.db,
          timeoutOnPushOnce: true,
        ),
      );
      expect(store.inserts, 1,
          reason: 'the row was committed before the timeout');
      final SyncEvent pending =
          (await deviceA.eventRepo
                  .getRetryableByUserId('user-1', now: _farFuture))
              .single;
      expect(pending.status, SyncStatus.failedRetryable);
      expect(pending.retryCount, 1);

      // Simulated restart: fresh engine on the same DB, healthy transport.
      await _makeDue(deviceA);
      final SyncEngine restarted = deviceA.engine();
      final SyncRunResult recovered = await restarted.sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(
              store: store,
              database: deviceA.db,
            ),
            applier: deviceA.applier,
          );
      expect(recovered.succeeded, 1);
      expect(store.rowsFor('weight_logs'), hasLength(1),
          reason: 'no duplicate cloud row after the retry');
      expect(store.inserts, 1,
          reason: 'a committed cloud mutation is never repeated');

      // The recovered record reaches device B.
      await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );
      expect(await _rows(deviceB, 'weight_log'), hasLength(1));
    });

    test('9. resetting the cursor re-applies remote changes and repairs a '
        'stale local row', () async {
      // Device A creates + completes a workout, pushing the mid-workout INSERT
      // first and the completion UPDATE second (as in the real capture order).
      final int whA = await _seedWorkoutHistory(deviceA.raw, uuid: 'wh-1');
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'workout_history',
            entityId: '$whA',
            operation: SyncOperation.create,
          );
      await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );
      final int end = DateTime.now().millisecondsSinceEpoch + 60000;
      await deviceA.raw.update(
        'workout_history',
        <String, Object?>{
          'ended_at': end,
          'duration_minutes': 1,
          'calories_burn': 4.5,
          'is_completed': 1,
          'updated_at': end,
          'row_version': 2,
        },
        where: 'uuid = ?',
        whereArgs: <Object?>['wh-1'],
      );
      await deviceA.engine().track(
            userId: 'user-1',
            entity: 'workout_history',
            entityId: '$whA',
            operation: SyncOperation.update,
            baseVersion: 1,
          );
      await deviceA.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceA.db),
            applier: deviceA.applier,
          );

      // Device B pulls everything and converges to the completed row.
      await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );
      List<Map<String, Object?>> rowsB = await _rows(deviceB, 'workout_history');
      expect(rowsB.single['is_completed'], 1);

      // Simulate the corruption: a stale local row (INSERT state, e.g. written
      // by an older build) with a cursor already past the completion UPDATE,
      // so an incremental pull has nothing left to re-apply.
      final int staleCursor = store
          .changesAfter(userId: 'user-1', cursor: 0)
          .last
          .id;
      await deviceB.raw.update(
        'workout_history',
        <String, Object?>{
          'is_completed': 0,
          'calories_burn': null,
          'row_version': 1,
        },
        where: 'uuid = ?',
        whereArgs: <Object?>['wh-1'],
      );
      await deviceB.stateRepo.upsert(
        SyncState(
          userId: 'user-1',
          cursor: staleCursor,
          initialSyncCompleted: true,
          updatedAt: DateTime.now(),
        ),
      );

      // A normal incremental sync must NOT repair the stale row.
      await deviceB.engine().sync(
            userId: 'user-1',
            transport: _CloudStoreTransport(store: store, database: deviceB.db),
            applier: deviceB.applier,
          );
      rowsB = await _rows(deviceB, 'workout_history');
      expect(rowsB.single['is_completed'], 0,
          reason: 'changes at/below the cursor are not re-pulled');

      // The reset path (engine.resetAndSync: push + cursor reset + fresh pull
      // under the per-user lock) re-applies everything in order and repairs
      // the row.
      final SyncRunResult reset = await deviceB.engine().resetAndSync(
            userId: 'user-1',
            transport: _CloudStoreTransport(
              store: store,
              database: deviceB.db,
            ),
            applier: deviceB.applier,
          );
      expect(reset.pulled, greaterThan(0));
      rowsB = await _rows(deviceB, 'workout_history');
      expect(rowsB.single['is_completed'], 1,
          reason: 'the fresh pull re-applies the completion UPDATE');
      expect(rowsB.single['calories_burn'], 4.5);
      expect((await deviceB.stateRepo.getByUserId('user-1'))!.cursor,
          staleCursor);
    });
  });
}