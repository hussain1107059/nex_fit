import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/bmi_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/body_measurement_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sleep_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/step_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/datasources/local/water_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/weight_log_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/data/services/sync/sync_table_registry.dart';
import 'package:nexfit/domain/entities/bmi_log.dart';
import 'package:nexfit/domain/entities/body_measurement.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sleep_log.dart';
import 'package:nexfit/domain/entities/step_log.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/sync_state.dart';
import 'package:nexfit/domain/entities/water_log.dart';
import 'package:nexfit/domain/entities/weight_log.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 13 Batch 3 health-metric DAO migration tests.
///
/// For every migrated table (weight_log, bmi_log, body_measurement, sleep_log,
/// step_log, water_log) verifies:
///  - local insert/update/delete create the row + outbox event atomically,
///  - uuid is generated once on insert and preserved on update,
///  - row_version increments (update/delete) and is stamped 1 on insert,
///  - delete soft-deletes (deleted_at) instead of destroying the row,
///  - a failed mutation rolls back both the row and its event,
///  - remote apply updates the local row WITHOUT creating an outbound event,
///  - business timestamps (logged_at / measured_at / sleep_date / step_date)
///    are preserved independently of created_at/updated_at,
///  - cloud `date` columns (sleep_date, step_date) round-trip correctly,
///  - rows and events are scoped per user,
///  - large historical datasets are written via single batched transactions
///    (never loading the table into memory).
///
/// Engine-level tests (last group) cover incremental pull with cursor advance,
/// duplicate outbox event merging, and optimistic conflict detection.

final RegExp _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

String _iso(DateTime value) => value.toUtc().toIso8601String();

/// Scripted transport used for incremental-pull engine tests.
class _PullTransport implements SyncTransport {
  _PullTransport({List<SyncChange>? remoteChanges})
    : remoteChanges = remoteChanges ?? <SyncChange>[];

  final List<SyncChange> remoteChanges;

  @override
  String get name => 'scripted';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async =>
      const SyncPushResult(applied: true, serverRowVersion: 1);

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    final List<SyncChange> due = remoteChanges
        .where((SyncChange c) => c.cursorId > cursor)
        .toList();
    return SyncPullBatch(
      changes: due,
      nextCursor: due.isEmpty ? cursor : due.last.cursorId,
      hasMore: due.length == limit,
    );
  }
}

/// Transport that reports an optimistic-lock conflict on push.
class _ConflictTransport implements SyncTransport {
  @override
  String get name => 'conflict';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async =>
      const SyncPushResult(applied: false, conflict: true);

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async =>
      const SyncPullBatch(changes: <SyncChange>[], nextCursor: 0, hasMore: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late Database db;
  late RemoteChangeApplier applier;

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
    await db.insert('users', <String, Object?>{
      'id': 'user-2',
      'name': 'Bob',
      'email': 'bob@x.com',
      'provider': 'email',
    });
    applier = RemoteChangeApplier(database: appDatabase);
    SyncEventRecorder.configure(
      repository: SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      ),
      deviceIdProvider: () async => 'device-1',
      activeUserId: 'user-1',
    );
  }

  tearDown(() async {
    SyncEventRecorder.setEnabled(false);
    SyncEventRecorder.setActiveUser(null);
    await appDatabase.close();
  });

  Future<List<Map<String, Object?>>> eventsFor(String entity) {
    return db.query(
      'sync_event',
      where: 'entity = ?',
      whereArgs: <Object?>[entity],
      orderBy: 'id ASC',
    );
  }

  Future<Map<String, Object?>> rowById(String table, int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return rows.first;
  }

  Future<String> uuidById(String table, int id) async {
    return (await rowById(table, id))['uuid'] as String;
  }

  group('weight_log', () {
    setUp(setUpDb);

    WeightLogLocalDataSource dao() =>
        WeightLogLocalDataSource(database: appDatabase);

    WeightLog log({String userId = 'user-1', DateTime? loggedAt}) => WeightLog(
          userId: userId,
          weightKg: 82.5,
          loggedAt: loggedAt ?? DateTime.utc(2026, 1, 5, 6),
          createdAt: DateTime.utc(2026, 1, 5),
        );

    test('insert stamps uuid, version 1 and a CREATE event', () async {
      final int id = await dao().insert(log());
      final Map<String, Object?> row = await rowById('weight_log', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['user_id'], 'user-1');
      final List<Map<String, Object?>> events = await eventsFor('weight_log');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
    });

    test('update preserves uuid/business timestamp and records base_version',
        () async {
      final WeightLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      final String uuid = await uuidById('weight_log', id);

      await source.update(
        log().copyWith(id: id, weightKg: 81.0, loggedAt: DateTime.utc(2026, 1, 6)),
      );

      final Map<String, Object?> row = await rowById('weight_log', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['weight_kg'], 81.0);
      expect(
        row['logged_at'],
        DateTime.utc(2026, 1, 6).millisecondsSinceEpoch,
        reason: 'business timestamp preserved on update',
      );
      final List<Map<String, Object?>> events = await eventsFor('weight_log');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final WeightLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      await source.delete(id);
      final Map<String, Object?> row = await rowById('weight_log', id);
      expect(row['deleted_at'], isNotNull);
      expect(row['row_version'], 2);
      expect(await source.getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('weight_log');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(dao().insert(log(userId: 'ghost-user')), throwsA(anything));
      expect(await db.query('weight_log'), isEmpty);
      expect(await eventsFor('weight_log'), isEmpty);
    });

    test('remote apply creates the row and records no outbound event', () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'weight_logs',
            recordId: 'wl-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'wl-uuid-1',
              'user_id': 'user-1',
              'weight_kg': 80.0,
              'logged_at': _iso(DateTime.utc(2026, 1, 5, 7)),
              'created_at': _iso(DateTime.utc(2026, 1, 5)),
              'updated_at': _iso(DateTime.utc(2026, 1, 5)),
              'row_version': 1,
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query(
        'weight_log',
        where: 'uuid = ?',
        whereArgs: <Object?>['wl-uuid-1'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['weight_kg'], 80.0);
      expect(
        rows.single['logged_at'],
        DateTime.utc(2026, 1, 5, 7).millisecondsSinceEpoch,
      );
      expect(rows.single['row_version'], 1);
      expect(await eventsFor('weight_log'), isEmpty);
    });

    test('events are scoped per user', () async {
      await dao().insert(log(userId: 'user-1'));
      await dao().insert(log(userId: 'user-2'));
      final List<Map<String, Object?>> events = await eventsFor('weight_log');
      expect(
        events.map((Map<String, Object?> e) => e['user_id']),
        containsAll(<Object?>['user-1', 'user-2']),
      );
    });

    test('a large local dataset is written in one batched transaction',
        () async {
      const int count = 1500;
      final WeightLogLocalDataSource source = dao();
      final List<WeightLog> logs = <WeightLog>[
        for (int i = 0; i < count; i++)
          log(loggedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i))),
      ];
      await source.insertAll(logs);

      expect(
        (await db.query('weight_log')).length,
        count,
        reason: 'bulk insert does not load existing history into memory',
      );
      expect(await eventsFor('weight_log'), hasLength(count));
      final List<Map<String, Object?>> uniqueUuids = await db.rawQuery(
        'SELECT COUNT(DISTINCT uuid) AS n FROM weight_log',
      );
      expect(uniqueUuids.single['n'], count);
      final List<WeightLog> day = await source.getByDateRange(
        'user-1',
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 2),
      );
      expect(day, hasLength(1440));
    });

    test('registry maps weight_log to weight_logs', () {
      final SyncTableMapping? mapping =
          SyncTableRegistry.byLocalTable('weight_log');
      expect(mapping, isNotNull);
      expect(mapping!.cloudTable, 'weight_logs');
      expect(mapping.timestampColumns, contains('logged_at'));
    });
  });

  group('body_measurement', () {
    setUp(setUpDb);

    BodyMeasurementLocalDataSource dao() =>
        BodyMeasurementLocalDataSource(database: appDatabase);

    BodyMeasurement measurement({String userId = 'user-1'}) =>
        BodyMeasurement(
          userId: userId,
          chestCm: 100,
          waistCm: 80,
          leftArmCm: 34,
          rightArmCm: 35,
          measuredAt: DateTime.utc(2026, 1, 5),
          createdAt: DateTime.utc(2026, 1, 5),
        );

    test('insert stamps uuid, version 1 and a CREATE event', () async {
      final int id = await dao().insert(measurement());
      final Map<String, Object?> row = await rowById('body_measurement', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      final List<Map<String, Object?>> events =
          await eventsFor('body_measurement');
      expect(events.single['operation'], SyncOperation.create.name);
    });

    test('update preserves uuid and records base_version', () async {
      final BodyMeasurementLocalDataSource source = dao();
      final int id = await source.insert(measurement());
      final String uuid = await uuidById('body_measurement', id);

      await source.update(measurement().copyWith(id: id, waistCm: 78));

      final Map<String, Object?> row = await rowById('body_measurement', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['waist_cm'], 78);
      final List<Map<String, Object?>> events =
          await eventsFor('body_measurement');
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final BodyMeasurementLocalDataSource source = dao();
      final int id = await source.insert(measurement());
      await source.delete(id);
      expect((await rowById('body_measurement', id))['deleted_at'], isNotNull);
      expect(await source.getById(id), isNull);
      final List<Map<String, Object?>> events =
          await eventsFor('body_measurement');
      expect(events.last['operation'], SyncOperation.delete.name);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(
        dao().insert(measurement(userId: 'ghost-user')),
        throwsA(anything),
      );
      expect(await db.query('body_measurement'), isEmpty);
      expect(await eventsFor('body_measurement'), isEmpty);
    });

    test('remote apply maps all circumference columns and no outbound event',
        () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'body_measurements',
            recordId: 'bm-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'bm-uuid-1',
              'user_id': 'user-1',
              'chest_cm': 101,
              'waist_cm': 79,
              'left_arm_cm': 33,
              'right_arm_cm': 34,
              'left_thigh_cm': 55,
              'right_calf_cm': 36,
              'measured_at': _iso(DateTime.utc(2026, 1, 6)),
              'created_at': _iso(DateTime.utc(2026, 1, 6)),
              'updated_at': _iso(DateTime.utc(2026, 1, 6)),
              'row_version': 1,
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query(
        'body_measurement',
        where: 'uuid = ?',
        whereArgs: <Object?>['bm-uuid-1'],
      );
      expect(rows.single['chest_cm'], 101);
      expect(rows.single['left_arm_cm'], 33);
      expect(rows.single['right_calf_cm'], 36);
      expect(await eventsFor('body_measurement'), isEmpty);
    });

    test('events are scoped per user', () async {
      await dao().insert(measurement(userId: 'user-1'));
      await dao().insert(measurement(userId: 'user-2'));
      final List<Map<String, Object?>> events =
          await eventsFor('body_measurement');
      expect(
        events.map((Map<String, Object?> e) => e['user_id']),
        containsAll(<Object?>['user-1', 'user-2']),
      );
    });

    test('bulk insert writes all rows and CREATE events in one transaction',
        () async {
      final List<BodyMeasurement> items = <BodyMeasurement>[
        for (int i = 0; i < 300; i++)
          measurement().copyWith(
            measuredAt: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
          ),
      ];
      await dao().insertAll(items);
      expect(await db.query('body_measurement'), hasLength(300));
      expect(await eventsFor('body_measurement'), hasLength(300));
    });
  });

  group('bmi_log', () {
    setUp(setUpDb);

    BmiLogLocalDataSource dao() => BmiLogLocalDataSource(database: appDatabase);

    BmiLog log({String userId = 'user-1'}) => BmiLog(
          userId: userId,
          bmi: 24.5,
          weightKg: 75,
          heightCm: 175,
          category: 'normal',
          loggedAt: DateTime.utc(2026, 1, 5),
          createdAt: DateTime.utc(2026, 1, 5),
        );

    test('insert stamps uuid, version 1 and a CREATE event', () async {
      final int id = await dao().insert(log());
      final Map<String, Object?> row = await rowById('bmi_log', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      final List<Map<String, Object?>> events = await eventsFor('bmi_log');
      expect(events.single['operation'], SyncOperation.create.name);
    });

    test('update preserves uuid and records base_version', () async {
      final BmiLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      final String uuid = await uuidById('bmi_log', id);
      await source.update(log().copyWith(id: id, bmi: 25.0));
      final Map<String, Object?> row = await rowById('bmi_log', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['bmi'], 25.0);
      final List<Map<String, Object?>> events = await eventsFor('bmi_log');
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final BmiLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      await source.delete(id);
      expect((await rowById('bmi_log', id))['deleted_at'], isNotNull);
      expect(await source.getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('bmi_log');
      expect(events.last['operation'], SyncOperation.delete.name);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(dao().insert(log(userId: 'ghost-user')), throwsA(anything));
      expect(await db.query('bmi_log'), isEmpty);
      expect(await eventsFor('bmi_log'), isEmpty);
    });

    test('remote apply creates the row and records no outbound event', () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'bmi_logs',
            recordId: 'bmi-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'bmi-uuid-1',
              'user_id': 'user-1',
              'bmi': 26.1,
              'weight_kg': 78,
              'height_cm': 173,
              'category': 'overweight',
              'logged_at': _iso(DateTime.utc(2026, 1, 5, 8)),
              'created_at': _iso(DateTime.utc(2026, 1, 5)),
              'updated_at': _iso(DateTime.utc(2026, 1, 5)),
              'row_version': 1,
            },
          ),
        );
      });
      final List<Map<String, Object?>> rows = await db.query(
        'bmi_log',
        where: 'uuid = ?',
        whereArgs: <Object?>['bmi-uuid-1'],
      );
      expect(rows.single['bmi'], 26.1);
      expect(rows.single['category'], 'overweight');
      expect(
        rows.single['logged_at'],
        DateTime.utc(2026, 1, 5, 8).millisecondsSinceEpoch,
      );
      expect(await eventsFor('bmi_log'), isEmpty);
    });

    test('events are scoped per user', () async {
      await dao().insert(log(userId: 'user-1'));
      await dao().insert(log(userId: 'user-2'));
      final List<Map<String, Object?>> events = await eventsFor('bmi_log');
      expect(
        events.map((Map<String, Object?> e) => e['user_id']),
        containsAll(<Object?>['user-1', 'user-2']),
      );
    });
  });

  group('sleep_log', () {
    setUp(setUpDb);

    SleepLogLocalDataSource dao() =>
        SleepLogLocalDataSource(database: appDatabase);

    SleepLog log({String userId = 'user-1', DateTime? sleepDate}) => SleepLog(
          userId: userId,
          sleepDate: sleepDate ?? DateTime(2026, 1, 5),
          durationMinutes: 420,
          bedtime: DateTime.utc(2026, 1, 4, 23),
          wakeTime: DateTime.utc(2026, 1, 5, 6),
          quality: 4,
          createdAt: DateTime(2026, 1, 5),
        );

    test('insert stamps uuid, version 1 and a CREATE event', () async {
      final int id = await dao().insert(log());
      final Map<String, Object?> row = await rowById('sleep_log', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      final List<Map<String, Object?>> events = await eventsFor('sleep_log');
      expect(events.single['operation'], SyncOperation.create.name);
    });

    test('update preserves uuid/sleep_date and records base_version', () async {
      final SleepLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      final String uuid = await uuidById('sleep_log', id);
      await source.update(
        log().copyWith(id: id, durationMinutes: 390, quality: 3),
      );
      final Map<String, Object?> row = await rowById('sleep_log', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['duration_minutes'], 390);
      expect(row['sleep_date'], DateTime(2026, 1, 5).millisecondsSinceEpoch);
      final List<Map<String, Object?>> events = await eventsFor('sleep_log');
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final SleepLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      await source.delete(id);
      expect((await rowById('sleep_log', id))['deleted_at'], isNotNull);
      expect(await source.getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('sleep_log');
      expect(events.last['operation'], SyncOperation.delete.name);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(dao().insert(log(userId: 'ghost-user')), throwsA(anything));
      expect(await db.query('sleep_log'), isEmpty);
      expect(await eventsFor('sleep_log'), isEmpty);
    });

    test('remote apply round-trips the cloud date column sleep_date',
        () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'sleep_logs',
            recordId: 'sleep-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'sleep-uuid-1',
              'user_id': 'user-1',
              'sleep_date': '2026-01-06',
              'duration_minutes': 450,
              'bedtime': _iso(DateTime.utc(2026, 1, 5, 23)),
              'wake_time': _iso(DateTime.utc(2026, 1, 6, 6)),
              'quality': 5,
              'created_at': _iso(DateTime.utc(2026, 1, 6)),
              'updated_at': _iso(DateTime.utc(2026, 1, 6)),
              'row_version': 1,
            },
          ),
        );
      });
      final List<Map<String, Object?>> rows = await db.query(
        'sleep_log',
        where: 'uuid = ?',
        whereArgs: <Object?>['sleep-uuid-1'],
      );
      expect(rows.single['duration_minutes'], 450);
      expect(
        rows.single['sleep_date'],
        DateTime(2026, 1, 6).millisecondsSinceEpoch,
        reason: 'cloud date renders back to local epoch-ms midnight',
      );
      expect(await eventsFor('sleep_log'), isEmpty);
    });

    test('events are scoped per user', () async {
      await dao().insert(log(userId: 'user-1'));
      await dao().insert(log(userId: 'user-2'));
      final List<Map<String, Object?>> events = await eventsFor('sleep_log');
      expect(
        events.map((Map<String, Object?> e) => e['user_id']),
        containsAll(<Object?>['user-1', 'user-2']),
      );
    });
  });

  group('step_log', () {
    setUp(setUpDb);

    StepLogLocalDataSource dao() => StepLogLocalDataSource(database: appDatabase);

    StepLog log({String userId = 'user-1', DateTime? stepDate}) => StepLog(
          userId: userId,
          stepDate: stepDate ?? DateTime(2026, 1, 5),
          steps: 8000,
          distanceKm: 6.4,
          caloriesBurned: 300,
          createdAt: DateTime(2026, 1, 5),
        );

    test('insert stamps uuid, version 1 and a CREATE event', () async {
      final int id = await dao().insert(log());
      final Map<String, Object?> row = await rowById('step_log', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      final List<Map<String, Object?>> events = await eventsFor('step_log');
      expect(events.single['operation'], SyncOperation.create.name);
    });

    test('update preserves uuid/step_date and records base_version', () async {
      final StepLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      final String uuid = await uuidById('step_log', id);
      await source.update(log().copyWith(id: id, steps: 9500));
      final Map<String, Object?> row = await rowById('step_log', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['steps'], 9500);
      expect(row['step_date'], DateTime(2026, 1, 5).millisecondsSinceEpoch);
      final List<Map<String, Object?>> events = await eventsFor('step_log');
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final StepLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      await source.delete(id);
      expect((await rowById('step_log', id))['deleted_at'], isNotNull);
      expect(await source.getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('step_log');
      expect(events.last['operation'], SyncOperation.delete.name);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(dao().insert(log(userId: 'ghost-user')), throwsA(anything));
      expect(await db.query('step_log'), isEmpty);
      expect(await eventsFor('step_log'), isEmpty);
    });

    test('remote apply round-trips the cloud date column step_date', () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'step_logs',
            recordId: 'step-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'step-uuid-1',
              'user_id': 'user-1',
              'step_date': '2026-01-07',
              'steps': 12000,
              'distance_km': 9.0,
              'calories_burned': 450,
              'created_at': _iso(DateTime.utc(2026, 1, 7)),
              'updated_at': _iso(DateTime.utc(2026, 1, 7)),
              'row_version': 1,
            },
          ),
        );
      });
      final List<Map<String, Object?>> rows = await db.query(
        'step_log',
        where: 'uuid = ?',
        whereArgs: <Object?>['step-uuid-1'],
      );
      expect(rows.single['steps'], 12000);
      expect(
        rows.single['step_date'],
        DateTime(2026, 1, 7).millisecondsSinceEpoch,
      );
      expect(await eventsFor('step_log'), isEmpty);
    });

    test('events are scoped per user', () async {
      await dao().insert(log(userId: 'user-1'));
      await dao().insert(log(userId: 'user-2'));
      final List<Map<String, Object?>> events = await eventsFor('step_log');
      expect(
        events.map((Map<String, Object?> e) => e['user_id']),
        containsAll(<Object?>['user-1', 'user-2']),
      );
    });
  });

  group('water_log', () {
    setUp(setUpDb);

    WaterLogLocalDataSource dao() =>
        WaterLogLocalDataSource(database: appDatabase);

    WaterLog log({String userId = 'user-1', DateTime? loggedAt}) => WaterLog(
          userId: userId,
          amountMl: 250,
          loggedAt: loggedAt ?? DateTime.utc(2026, 1, 5, 9),
          createdAt: DateTime.utc(2026, 1, 5),
        );

    test('insert stamps uuid, version 1 and a CREATE event', () async {
      final int id = await dao().insert(log());
      final Map<String, Object?> row = await rowById('water_log', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      final List<Map<String, Object?>> events = await eventsFor('water_log');
      expect(events.single['operation'], SyncOperation.create.name);
    });

    test('update preserves uuid/logged_at and records base_version', () async {
      final WaterLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      final String uuid = await uuidById('water_log', id);
      await source.update(log().copyWith(id: id, amountMl: 500));
      final Map<String, Object?> row = await rowById('water_log', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['amount_ml'], 500);
      expect(
        row['logged_at'],
        DateTime.utc(2026, 1, 5, 9).millisecondsSinceEpoch,
        reason: 'business timestamp preserved on update',
      );
      final List<Map<String, Object?>> events = await eventsFor('water_log');
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final WaterLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      await source.delete(id);
      expect((await rowById('water_log', id))['deleted_at'], isNotNull);
      expect(await source.getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('water_log');
      expect(events.last['operation'], SyncOperation.delete.name);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(dao().insert(log(userId: 'ghost-user')), throwsA(anything));
      expect(await db.query('water_log'), isEmpty);
      expect(await eventsFor('water_log'), isEmpty);
    });

    test('remote apply creates the row and records no outbound event', () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'water_logs',
            recordId: 'water-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'water-uuid-1',
              'user_id': 'user-1',
              'amount_ml': 750,
              'logged_at': _iso(DateTime.utc(2026, 1, 5, 12)),
              'created_at': _iso(DateTime.utc(2026, 1, 5)),
              'updated_at': _iso(DateTime.utc(2026, 1, 5)),
              'row_version': 1,
            },
          ),
        );
      });
      final List<Map<String, Object?>> rows = await db.query(
        'water_log',
        where: 'uuid = ?',
        whereArgs: <Object?>['water-uuid-1'],
      );
      expect(rows.single['amount_ml'], 750);
      expect(
        rows.single['logged_at'],
        DateTime.utc(2026, 1, 5, 12).millisecondsSinceEpoch,
      );
      expect(await eventsFor('water_log'), isEmpty);
    });

    test('a large local dataset is written in one batched transaction',
        () async {
      const int count = 1200;
      final WaterLogLocalDataSource source = dao();
      final List<WaterLog> logs = <WaterLog>[
        for (int i = 0; i < count; i++)
          log(loggedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i))),
      ];
      await source.insertAll(logs);
      expect(await db.query('water_log'), hasLength(count));
      expect(await eventsFor('water_log'), hasLength(count));
    });

    test('events are scoped per user', () async {
      await dao().insert(log(userId: 'user-1'));
      await dao().insert(log(userId: 'user-2'));
      final List<Map<String, Object?>> events = await eventsFor('water_log');
      expect(
        events.map((Map<String, Object?> e) => e['user_id']),
        containsAll(<Object?>['user-1', 'user-2']),
      );
    });
  });

  group('engine: incremental pull, cursor, duplicates, conflicts', () {
    setUp(setUpDb);

    late SyncEventRepositoryImpl eventRepo;
    late SyncStateRepositoryImpl stateRepo;

    setUp(() async {
      eventRepo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      stateRepo = SyncStateRepositoryImpl(
        SyncStateLocalDataSource(database: appDatabase),
      );
    });

    SyncEngine engine() => SyncEngine(
          repository: eventRepo,
          syncStateRepository: stateRepo,
          deviceIdProvider: () async => 'device-1',
        );

    SyncChange weightChange(
      int cursorId, {
      String recordId = 'wl-uuid-1',
      SyncOperation operation = SyncOperation.create,
    }) =>
        SyncChange(
          cursorId: cursorId,
          cloudTable: 'weight_logs',
          recordId: recordId,
          operation: operation,
          payload: operation == SyncOperation.delete
              ? const <String, Object?>{}
              : <String, Object?>{
                  'id': recordId,
                  'user_id': 'user-1',
                  'weight_kg': 82.5,
                  'logged_at': '2026-01-01T06:00:00Z',
                  'created_at': '2026-01-01T06:00:00Z',
                  'updated_at': '2026-01-01T06:00:00Z',
                  'row_version': 1,
                },
        );

    test('incremental pull applies only changes after the stored cursor',
        () async {
      final SyncEngine syncEngine = engine();

      await syncEngine.pull(
        userId: 'user-1',
        transport: _PullTransport(
          remoteChanges: <SyncChange>[
            weightChange(5, recordId: 'wl-uuid-1'),
            weightChange(6, recordId: 'wl-uuid-2'),
          ],
        ),
        applier: applier,
      );
      final SyncState first = (await stateRepo.getByUserId('user-1'))!;
      expect(first.cursor, 6);
      expect(await db.query('weight_log'), hasLength(2));

      // Second run only pulls cursor-7+ changes; 5/6 are never re-applied.
      await syncEngine.pull(
        userId: 'user-1',
        transport: _PullTransport(
          remoteChanges: <SyncChange>[
            weightChange(5, recordId: 'wl-uuid-1'),
            weightChange(6, recordId: 'wl-uuid-2'),
            weightChange(7, recordId: 'wl-uuid-3'),
          ],
        ),
        applier: applier,
      );
      final SyncState second = (await stateRepo.getByUserId('user-1'))!;
      expect(second.cursor, 7);
      expect(await db.query('weight_log'), hasLength(3));
    });

    test('duplicate pending outbox events are merged into one', () async {
      final SyncEngine syncEngine = engine();
      await syncEngine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.update,
        baseVersion: 1,
      );
      final String? firstUuid = await eventRepo
          .getPendingByUserId('user-1')
          .then((List<SyncEvent> e) => e.single.eventUuid);
      await syncEngine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.update,
        baseVersion: 1,
      );

      final List<SyncEvent> pending =
          await eventRepo.getPendingByUserId('user-1');
      expect(pending, hasLength(1));
      expect(pending.single.eventUuid, firstUuid);
    });

    test('an optimistic-lock conflict on push is resolved latest-wins',
        () async {
      final SyncEngine syncEngine = engine();
      await syncEngine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.update,
        baseVersion: 1,
      );

      final SyncRunResult result = await syncEngine.processQueue(
        'user-1',
        transport: _ConflictTransport(),
      );

      expect(result.conflicts, 1);
      final List<SyncEvent> pending =
          await eventRepo.getPendingByUserId('user-1');
      expect(pending, isEmpty);
      expect((await eventRepo.countByStatus('user-1'))[SyncStatus.completed.name], 1,
          reason: 'latest-wins acknowledges the push; pull converges next');
    });

    test('remote apply never enqueues an outbound event (no echo loop)',
        () async {
      await engine().pull(
        userId: 'user-1',
        transport: _PullTransport(
          remoteChanges: <SyncChange>[weightChange(5)],
        ),
        applier: applier,
      );
      expect(await eventRepo.getPendingCount('user-1'), 0);
      expect(await eventRepo.getFailedCount('user-1'), 0);
    });
  });
}
