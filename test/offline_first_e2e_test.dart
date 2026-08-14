import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/fitness_goal_local_data_source.dart';
import 'package:nexfit/data/datasources/local/food_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sleep_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/step_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_conflict_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/datasources/local/water_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/weight_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_conflict_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/data/services/sync/sync_table_registry.dart';
import 'package:nexfit/domain/entities/common_enums.dart';
import 'package:nexfit/domain/entities/fitness_goal.dart';
import 'package:nexfit/domain/entities/food_log.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sleep_log.dart';
import 'package:nexfit/domain/entities/step_log.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/water_log.dart';
import 'package:nexfit/domain/entities/weight_log.dart';
import 'package:nexfit/domain/entities/workout.dart';
import 'package:nexfit/domain/repositories/sync_conflict_repository.dart';
import 'package:nexfit/domain/repositories/sync_event_repository.dart';
import 'package:nexfit/domain/repositories/sync_state_repository.dart';

/// PROMPT 25 — Offline-first end-to-end audit.
///
/// A full user journey on top of the **real DAO layer** (the same code the app
/// reads and writes through) with a Supabase-like cloud and a network-flapping
/// transport:
///
/// 1. Offline-first reads — while offline the app remains fully usable:
///    creates, edits and deletes across six entity types are recorded, and the
///    read path immediately reflects them from the local database.
/// 2. Offline sync — a "Sync now" run while offline uploads nothing; every
///    mutation is retained durably in the outbox.
/// 3. Reconnect convergence — once back online everything uploads exactly
///    once and a second device converges to the exact same state (created /
///    edited / soft-deleted rows).
/// 4. Flapping network — a single run whose push succeeds but whose pull fails
///    is reported as a partial failure and a later retry recovers without
///    losing data or creating duplicate cloud rows.
///
/// See `docs/NEXFIT_OFFLINE_FIRST_E2E_TEST.md`.

final DateTime _farFuture = DateTime.now().add(const Duration(days: 30));

// ---------------------------------------------------------------------------
// Supabase-like cloud + flappable transport (same model as the PROMPT 23
// harness: idempotent upserts, optimistic row_version, tombstones, keyset
// paginated feed).
// ---------------------------------------------------------------------------

class _CloudRow {
  _CloudRow(this.data, this.version);
  final Map<String, Object?> data;
  int version;
}

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

class _CloudStore {
  final Map<String, Map<String, _CloudRow>> _rows =
      <String, Map<String, _CloudRow>>{};
  final List<_CloudChange> _changes = <_CloudChange>[];
  int _nextId = 1;
  int inserts = 0;

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

class _FlappableTransport implements SyncTransport {
  _FlappableTransport({required this.store, required this.database});

  final _CloudStore store;
  final AppDatabase database;
  bool networkDown = false;
  bool failPullOnce = false;
  bool _pullFailed = false;
  int pushCalls = 0;

  @override
  String get name => 'flappable';

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

  Object? _convert(SyncTableMapping mapping, String cloudColumn, Object? value) {
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

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    pushCalls++;
    final SyncTableMapping? mapping =
        SyncTableRegistry.byLocalTable(event.entity);
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
    final _CloudRow? existing = store.rowsFor(mapping.cloudTable)[recordId];

    if (event.operation == SyncOperation.create || event.baseVersion == 0) {
      final int version = (existing?.version ?? 0) + 1;
      cloudRow['row_version'] = version;
      store.put(mapping.cloudTable, recordId, _CloudRow(cloudRow, version));
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
        store.appendChange(
          table: mapping.cloudTable,
          recordId: recordId,
          operation: 'UPDATE',
          userId: event.userId,
          payload: cloudRow,
        );
      }
      return SyncPushResult(applied: true, serverRowVersion: version);
    }

    if (existing == null) {
      return const SyncPushResult(applied: false, conflict: true);
    }
    if (existing.version != event.baseVersion) {
      return SyncPushResult(
        applied: false,
        conflict: true,
        serverRowVersion: existing.version,
        serverData: Map<String, Object?>.of(existing.data),
      );
    }
    final int version = existing.version + 1;
    cloudRow['row_version'] = version;
    store.put(mapping.cloudTable, recordId, _CloudRow(cloudRow, version));
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
    final String? recordId = localRow?['uuid'] as String?;
    if (recordId == null) return const SyncPushResult(applied: true);
    final _CloudRow? existing = store.rowsFor(mapping.cloudTable)[recordId];
    if (existing == null) return const SyncPushResult(applied: true);
    if (existing.version != event.baseVersion) {
      return SyncPushResult(
        applied: false,
        conflict: true,
        serverRowVersion: existing.version,
        serverData: Map<String, Object?>.of(existing.data),
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
    if (networkDown) {
      throw const SyncTransportException('network_unreachable');
    }
    if (failPullOnce && !_pullFailed) {
      _pullFailed = true;
      throw const SyncTransportException('network_unreachable');
    }
    final List<_CloudChange> changes = store.changesAfter(
      userId: userId,
      cursor: cursor,
      limit: limit,
    );
    return SyncPullBatch(
      changes: <SyncChange>[
        for (final _CloudChange change in changes)
          SyncChange(
            cursorId: change.id,
            cloudTable: change.table,
            recordId: change.recordId,
            operation: _operationFrom(change.operation),
            payload: Map<String, Object?>.of(change.payload),
          ),
      ],
      nextCursor: changes.isEmpty ? cursor : changes.last.id,
      hasMore: changes.length == limit,
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

// ---------------------------------------------------------------------------
// A logical device (its own SQLite database + full sync stack).
// ---------------------------------------------------------------------------

class _UserDevice {
  _UserDevice(this.name);

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
    eventRepo = SyncEventRepositoryImpl(SyncEventLocalDataSource(database: db));
    stateRepo = SyncStateRepositoryImpl(SyncStateLocalDataSource(database: db));
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

Future<void> _makeDue(_UserDevice device) async {
  for (final SyncEvent event
      in await device.eventRepo.getRetryableByUserId('user-1', now: _farFuture)) {
    await device.eventRepo.update(event.copyWith(clearNextRetryAt: true));
  }
}

// ---------------------------------------------------------------------------
// Real DAO usage — the same data sources the app reads and writes through.
// ---------------------------------------------------------------------------

WeightLog _weightLog({double weightKg = 82.5}) => WeightLog(
      userId: 'user-1',
      weightKg: weightKg,
      loggedAt: DateTime.utc(2026, 1, 5, 6),
      createdAt: DateTime.utc(2026, 1, 5),
    );

FoodLog _foodLog() => FoodLog(
      userId: 'user-1',
      quantity: 1,
      calories: 200,
      protein: 5,
      carbs: 40,
      fat: 1,
      loggedAt: DateTime.utc(2026, 1, 5, 8),
      createdAt: DateTime.utc(2026, 1, 5),
    );

WaterLog _waterLog({int amountMl = 250}) => WaterLog(
      userId: 'user-1',
      amountMl: amountMl,
      loggedAt: DateTime.utc(2026, 1, 5, 9),
      createdAt: DateTime.utc(2026, 1, 5),
    );

SleepLog _sleepLog() => SleepLog(
      userId: 'user-1',
      sleepDate: DateTime(2026, 1, 5),
      durationMinutes: 420,
      bedtime: DateTime.utc(2026, 1, 4, 23),
      wakeTime: DateTime.utc(2026, 1, 5, 6),
      quality: 4,
      createdAt: DateTime(2026, 1, 5),
    );

StepLog _stepLog() => StepLog(
      userId: 'user-1',
      stepDate: DateTime(2026, 1, 5),
      steps: 8000,
      distanceKm: 6.4,
      caloriesBurned: 300,
      createdAt: DateTime(2026, 1, 5),
    );

FitnessGoal _goal() => FitnessGoal(
      userId: 'user-1',
      title: 'Lose 5kg',
      goalType: GoalType.weightLoss,
      currentValue: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

Workout _workout() => Workout(
      userId: 'user-1',
      name: 'Morning Cardio',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

/// Runs the user's offline session: creates across six entity types, edits one
/// row and deletes another — all through the real DAOs.
Future<void> _recordOfflineSession(_UserDevice device) async {
  final WeightLogLocalDataSource weight =
      WeightLogLocalDataSource(database: device.db);
  final FoodLogLocalDataSource food = FoodLogLocalDataSource(database: device.db);
  final WaterLogLocalDataSource water = WaterLogLocalDataSource(database: device.db);
  final SleepLogLocalDataSource sleep = SleepLogLocalDataSource(database: device.db);
  final StepLogLocalDataSource step = StepLogLocalDataSource(database: device.db);
  final FitnessGoalLocalDataSource goal =
      FitnessGoalLocalDataSource(database: device.db);
  final WorkoutLocalDataSource workout = WorkoutLocalDataSource(database: device.db);

  final int weightId = await weight.insert(_weightLog());
  await food.insert(_foodLog());
  final int waterId = await water.insert(_waterLog());
  await sleep.insert(_sleepLog());
  await step.insert(_stepLog());
  await goal.insert(_goal());
  await workout.insert(_workout());

  // Offline edit: weight corrected to 81.0.
  await weight.update(_weightLog(weightKg: 81.0).copyWith(id: weightId));

  // Offline delete: a water glass removed.
  await water.delete(waterId);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late _UserDevice phone; // produces the offline session
  late _UserDevice tablet; // converges after reconnect
  late _CloudStore store;

  setUp(() async {
    store = _CloudStore();
    phone = _UserDevice('phone');
    tablet = _UserDevice('tablet');
    await phone.init();
    await tablet.init();
    SyncEventRecorder.configure(
      repository: phone.eventRepo,
      deviceIdProvider: () async => 'device-phone',
      activeUserId: 'user-1',
    );
  });

  tearDown(() async {
    SyncEventRecorder.setEnabled(false);
    SyncEventRecorder.setActiveUser(null);
    await phone.close();
    await tablet.close();
  });

  group('offline-first end-to-end', () {
    test('1. offline-first reads: the app is fully usable offline '
        '(create + edit + delete, reads reflect it immediately)', () async {
      await _recordOfflineSession(phone);

      final WeightLogLocalDataSource weight =
          WeightLogLocalDataSource(database: phone.db);
      final FoodLogLocalDataSource food =
          FoodLogLocalDataSource(database: phone.db);
      final WaterLogLocalDataSource water =
          WaterLogLocalDataSource(database: phone.db);
      final SleepLogLocalDataSource sleep =
          SleepLogLocalDataSource(database: phone.db);
      final StepLogLocalDataSource step =
          StepLogLocalDataSource(database: phone.db);
      final FitnessGoalLocalDataSource goal =
          FitnessGoalLocalDataSource(database: phone.db);
      final WorkoutLocalDataSource workout =
          WorkoutLocalDataSource(database: phone.db);

      expect((await weight.getByUserId('user-1')).single.weightKg, 81.0,
          reason: 'offline edit is visible through the read path');
      expect((await food.getByUserId('user-1')).single.calories, 200);
      expect(await water.getByUserId('user-1'), isEmpty,
          reason: 'offline delete hides the row from the read path');
      expect((await sleep.getByUserId('user-1')).single.durationMinutes, 420);
      expect((await step.getByUserId('user-1')).single.steps, 8000);
      expect((await goal.getByUserId('user-1')).single.title, 'Lose 5kg');
      expect((await workout.getByUserId('user-1')).single.name, 'Morning Cardio');

      // The outbox holds every mutation atomically: 7 creates + 1 update +
      // 1 delete, all pending and unscoped away from the device.
      final Map<String, int> counts =
          await phone.eventRepo.countByStatus('user-1');
      expect(counts[SyncStatus.pending.name], 9);
    });

    test('2. offline sync uploads nothing and retains every event; reconnect '
        'converges a second device to the exact same state', () async {
      await _recordOfflineSession(phone);

      // "Sync now" while offline: nothing reaches the cloud, everything is
      // retained durably in the outbox as retryable.
      final _FlappableTransport offline =
          _FlappableTransport(store: store, database: phone.db)
            ..networkDown = true;
      final SyncRunResult offlineRun =
          await phone.engine().sync(userId: 'user-1', transport: offline, applier: phone.applier);
      expect(offlineRun.failed, greaterThan(0));
      final Map<String, int> afterOffline =
          await phone.eventRepo.countByStatus('user-1');
      expect(afterOffline[SyncStatus.failedRetryable.name], 9,
          reason: 'all 9 offline mutations are durable and retryable');
      expect(store.changeCount, 0,
          reason: 'nothing was uploaded while offline');

      // Reconnect: the same events upload exactly once.
      await _makeDue(phone);
      final _FlappableTransport online =
          _FlappableTransport(store: store, database: phone.db);
      final SyncRunResult reconnect =
          await phone.engine().sync(userId: 'user-1', transport: online, applier: phone.applier);
      expect(reconnect.succeeded, 9);
      expect(store.inserts, 7, reason: '7 creates, exactly one cloud insert each');
      expect(store.changeCount, 9, reason: '7 inserts + 1 update + 1 delete');

      // Second device converges: created rows match, the edit is applied and
      // the deleted row is tombstoned.
      final SyncRunResult tabletRun = await tablet.engine().sync(
            userId: 'user-1',
            transport: _FlappableTransport(store: store, database: tablet.db),
            applier: tablet.applier,
          );
      expect(tabletRun.pulled, 9);

      final WeightLogLocalDataSource tWeight =
          WeightLogLocalDataSource(database: tablet.db);
      final FoodLogLocalDataSource tFood =
          FoodLogLocalDataSource(database: tablet.db);
      final SleepLogLocalDataSource tSleep =
          SleepLogLocalDataSource(database: tablet.db);
      final StepLogLocalDataSource tStep =
          StepLogLocalDataSource(database: tablet.db);
      final FitnessGoalLocalDataSource tGoal =
          FitnessGoalLocalDataSource(database: tablet.db);
      final WorkoutLocalDataSource tWorkout =
          WorkoutLocalDataSource(database: tablet.db);

      expect((await tWeight.getByUserId('user-1')).single.weightKg, 81.0,
          reason: 'the offline edit converged');
      expect((await tFood.getByUserId('user-1')).single.calories, 200);
      expect((await tSleep.getByUserId('user-1')).single.durationMinutes, 420);
      expect((await tStep.getByUserId('user-1')).single.steps, 8000);
      expect((await tGoal.getByUserId('user-1')).single.title, 'Lose 5kg');
      expect((await tWorkout.getByUserId('user-1')).single.name, 'Morning Cardio');

      // The deleted water row is soft-deleted (tombstone), never resurrected.
      final List<Map<String, Object?>> waterRows =
          await tablet.raw.query('water_log');
      expect(waterRows, hasLength(1));
      expect(waterRows.single['deleted_at'], isNotNull);
    });

    test('3. flapping network: a push-succeeds/pull-fails run is a partial '
        'failure, and a later retry recovers without duplicates', () async {
      final WeightLogLocalDataSource weight =
          WeightLogLocalDataSource(database: phone.db);
      for (int i = 0; i < 3; i++) {
        await weight.insert(
          _weightLog(weightKg: 80.0 + i).copyWith(
            loggedAt: DateTime.utc(2026, 1, 5, 6 + i),
          ),
        );
      }

      // First run: all three pushes commit, then the pull drops the network.
      final _FlappableTransport flaky =
          _FlappableTransport(store: store, database: phone.db)
            ..failPullOnce = true;
      final SyncRunResult first =
          await phone.engine().sync(userId: 'user-1', transport: flaky, applier: phone.applier);
      expect(first.succeeded, 3, reason: 'pushes committed');
      expect(first.failed, 1, reason: 'the failed pull is reported');
      expect(first.hasPulled, isFalse);
      expect(store.inserts, 3, reason: 'cloud rows were written before the drop');

      // Retry on a healthy transport: nothing re-uploaded, pull recovers,
      // and no duplicate rows appear anywhere.
      await _makeDue(phone);
      final _FlappableTransport healthy =
          _FlappableTransport(store: store, database: phone.db);
      final SyncRunResult retry =
          await phone.engine().sync(userId: 'user-1', transport: healthy, applier: phone.applier);
      expect(retry.succeeded, 0, reason: 'nothing left to push');
      expect(store.inserts, 3, reason: 'no duplicate cloud rows');
      expect(await phone.raw.query('weight_log'), hasLength(3));

      await tablet.engine().sync(
            userId: 'user-1',
            transport: _FlappableTransport(store: store, database: tablet.db),
            applier: tablet.applier,
          );
      expect(await tablet.raw.query('weight_log'), hasLength(3),
          reason: 'the tablet holds exactly the three records, no duplicates');
    });
  });
}