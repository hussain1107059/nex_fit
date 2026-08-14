import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/achievement_local_data_source.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/badge_local_data_source.dart';
import 'package:nexfit/data/datasources/local/challenge_local_data_source.dart';
import 'package:nexfit/data/datasources/local/daily_progress_local_data_source.dart';
import 'package:nexfit/data/datasources/local/reminder_history_local_data_source.dart';
import 'package:nexfit/data/datasources/local/reminder_local_data_source.dart';
import 'package:nexfit/data/datasources/local/reward_local_data_source.dart';
import 'package:nexfit/data/datasources/local/streak_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/datasources/local/xp_history_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/data/services/sync/sync_table_registry.dart';
import 'package:nexfit/domain/entities/achievement.dart';
import 'package:nexfit/domain/entities/badge.dart';
import 'package:nexfit/domain/entities/challenge.dart';
import 'package:nexfit/domain/entities/common_enums.dart';
import 'package:nexfit/domain/entities/daily_progress.dart';
import 'package:nexfit/domain/entities/reminder.dart';
import 'package:nexfit/domain/entities/reminder_history.dart';
import 'package:nexfit/domain/entities/reward.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/streak.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/sync_state.dart';
import 'package:nexfit/domain/entities/xp_history.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 14 Batch 4 DAO migration tests — reminders + gamification.
///
/// For the source-of-truth tables (reminder, reminder_history, reward,
/// xp_history) verifies the transactional outbox contract exactly like the
/// earlier batches: uuid stamped once on insert and preserved on update,
/// row_version 1 on insert and incremented afterwards, delete soft-deletes,
/// failed mutations roll back row + event, remote apply writes the local row
/// without creating an outbound event (no echo), and rows/events are scoped
/// per user. Cloud `date` columns (reminder start_date/end_date) and boolean
/// columns round-trip through the applier.
///
/// The derived-data group asserts the PROMPT 14 classifications: daily_progress
/// (a recomputable daily rollup), streak (a cache of the workout streak
/// recomputable from synced workout_history) and the hybrid gamification tables
/// (achievement, badge, challenge, milestone — server-authoritative master
/// definitions mirrored locally) are NOT sync source-of-truth, so writes must
/// never enqueue outbox events and the tables must not be registered.
///
/// Engine-level tests cover incremental pull with cursor advance (including a
/// reminder -> reminder_history parent/child batch), duplicate outbox event
/// merging and optimistic conflict handling.

final RegExp _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

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

  group('reminder', () {
    setUp(setUpDb);

    ReminderLocalDataSource dao() =>
        ReminderLocalDataSource(database: appDatabase);

    Reminder reminder({String userId = 'user-1'}) => Reminder(
          userId: userId,
          title: 'Workout',
          body: 'Time to train',
          reminderType: ReminderType.workout,
          time: '07:00',
          daysOfWeek: <int>[1, 3, 5],
          scheduleType: ReminderScheduleType.weekly,
          times: <String>['07:00', '19:00'],
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 31),
          monthDay: 15,
          icon: 'fitness_center',
          colorValue: 0xFF3A86FF,
          soundEnabled: true,
          vibrationEnabled: false,
          silentMode: false,
          showActionButtons: true,
          relatedScreen: '/workout',
          isEnabled: true,
          lastTriggeredAt: DateTime.utc(2026, 1, 5, 7),
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );

    test('insert stamps uuid, version 1 and a CREATE event', () async {
      final int id = await dao().insert(reminder());
      final Map<String, Object?> row = await rowById('reminder', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['user_id'], 'user-1');
      final List<Map<String, Object?>> events = await eventsFor('reminder');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
    });

    test('update preserves uuid and records base_version', () async {
      final int id = await dao().insert(reminder());
      final String uuid = await uuidById('reminder', id);

      await dao().update(
        reminder().copyWith(
          id: id,
          title: 'Workout updated',
          isEnabled: false,
          lastTriggeredAt: DateTime.utc(2026, 1, 6, 7),
        ),
      );

      final Map<String, Object?> row = await rowById('reminder', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['is_enabled'], 0);
      final List<Map<String, Object?>> events = await eventsFor('reminder');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final int id = await dao().insert(reminder());
      await dao().delete(id);

      final Map<String, Object?> row = await rowById('reminder', id);
      expect(row['deleted_at'], isNotNull);
      expect(await dao().getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('reminder');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(
        dao().insert(reminder(userId: 'ghost')),
        throwsA(isA<Object>()),
      );
      expect(await db.query('reminder'), isEmpty);
      expect(await eventsFor('reminder'), isEmpty);
    });

    test('remote apply maps all columns including dates/booleans, no outbound',
        () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'reminders',
            recordId: 'rem-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'rem-uuid-1',
              'user_id': 'user-1',
              'title': 'Morning water',
              'body': 'Drink up',
              'reminder_type': 'water',
              'time': '08:30',
              'days_of_week': '1,2,3',
              'schedule_type': 'weekly',
              'times': '["08:30","20:00"]',
              'start_date': '2026-02-01',
              'end_date': '2026-02-28',
              'month_day': 10,
              'icon': 'water_drop',
              'color_value': 4280391411,
              'sound_enabled': false,
              'vibration_enabled': true,
              'silent_mode': true,
              'show_action_buttons': false,
              'related_screen': '/water',
              'is_enabled': true,
              'last_triggered_at': '2026-02-02T08:30:00Z',
              'created_at': '2026-02-01T08:00:00Z',
              'updated_at': '2026-02-01T08:00:00Z',
              'deleted_at': null,
              'row_version': 1,
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query('reminder');
      expect(rows, hasLength(1));
      final Map<String, Object?> row = rows.single;
      expect(row['uuid'], 'rem-uuid-1');
      expect(row['title'], 'Morning water');
      expect(row['is_enabled'], 1);
      expect(row['sound_enabled'], 0);
      expect(row['silent_mode'], 1);
      expect(row['show_action_buttons'], 0);
      final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(
        row['start_date'] as int,
      );
      expect(startDate.year, 2026);
      expect(startDate.month, 2);
      expect(startDate.day, 1);
      expect(await eventsFor('reminder'), isEmpty);
    });

    test('events are scoped per user', () async {
      await dao().insert(reminder());
      await dao().insert(reminder(userId: 'user-2'));
      final List<Map<String, Object?>> events = await eventsFor('reminder');
      expect(events, hasLength(2));
      expect(events.every((e) => e['user_id'] == 'user-1'), isFalse,
          reason: 'recorder runs for the active user only');
    });
  });

  group('reminder_history', () {
    setUp(setUpDb);

    ReminderHistoryLocalDataSource dao() =>
        ReminderHistoryLocalDataSource(database: appDatabase);
    ReminderLocalDataSource reminderDao() =>
        ReminderLocalDataSource(database: appDatabase);

    Future<int> seedReminder({String userId = 'user-1'}) {
      return reminderDao().insert(
        Reminder(
          userId: userId,
          title: 'Workout',
          time: '07:00',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
    }

    ReminderHistory history({
      String userId = 'user-1',
      int? reminderId,
      DateTime? scheduledFor,
    }) =>
        ReminderHistory(
          userId: userId,
          reminderId: reminderId,
          status: ReminderHistoryStatus.missed,
          scheduledFor: scheduledFor ?? DateTime.utc(2026, 1, 5, 7),
          actedAt: null,
          createdAt: DateTime.utc(2026, 1, 5, 7),
        );

    test('insert stamps uuid, version 1 and a CREATE event', () async {
      final int reminderId = await seedReminder();
      final int id = await dao().insert(history(reminderId: reminderId));
      final Map<String, Object?> row = await rowById('reminder_history', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['reminder_id'], reminderId);
      expect(row['status'], 'missed');
      final List<Map<String, Object?>> events =
          await eventsFor('reminder_history');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
    });

    test('insertAll writes all rows and events in one transaction', () async {
      final int reminderId = await seedReminder();
      await dao().insertAll(<ReminderHistory>[
        history(reminderId: reminderId, scheduledFor: DateTime.utc(2026, 1, 5)),
        history(reminderId: reminderId, scheduledFor: DateTime.utc(2026, 1, 6)),
        history(reminderId: reminderId, scheduledFor: DateTime.utc(2026, 1, 7)),
      ]);
      final List<Map<String, Object?>> rows =
          await db.query('reminder_history');
      expect(rows, hasLength(3));
      expect(await eventsFor('reminder_history'), hasLength(3));
    });

    test('update preserves uuid and records base_version', () async {
      final int reminderId = await seedReminder();
      final int id = await dao().insert(history(reminderId: reminderId));
      final String uuid = await uuidById('reminder_history', id);

      await dao().update(
        history(reminderId: reminderId, scheduledFor: DateTime.utc(2026, 1, 5))
            .copyWith(
          id: id,
          status: ReminderHistoryStatus.completed,
          actedAt: DateTime.utc(2026, 1, 5, 7, 30),
        ),
      );

      final Map<String, Object?> row =
          await rowById('reminder_history', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['status'], 'completed');
      final List<Map<String, Object?>> events =
          await eventsFor('reminder_history');
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('deleteByReminderId soft-deletes rows and emits a DELETE event each',
        () async {
      final int reminderId = await seedReminder();
      await dao().insert(history(reminderId: reminderId, scheduledFor: DateTime.utc(2026, 1, 5)));
      await dao().insert(history(reminderId: reminderId, scheduledFor: DateTime.utc(2026, 1, 6)));

      await dao().deleteByReminderId(reminderId);

      final List<Map<String, Object?>> rows =
          await db.query('reminder_history');
      expect(rows, hasLength(2));
      expect(rows.every((r) => r['deleted_at'] != null), isTrue);
      expect(await dao().getByReminderId(reminderId), isEmpty);
      final List<Map<String, Object?>> events =
          await eventsFor('reminder_history');
      final List<Map<String, Object?>> deletes = events
          .where((e) => e['operation'] == SyncOperation.delete.name)
          .toList();
      expect(deletes, hasLength(2));
    });

    test('remote apply resolves the reminder FK and never echoes', () async {
      final int reminderId = await seedReminder();
      final String reminderUuid = await uuidById('reminder', reminderId);

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'reminder_history',
            recordId: 'rh-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'rh-uuid-1',
              'user_id': 'user-1',
              'reminder_id': reminderUuid,
              'status': 'completed',
              'scheduled_for': '2026-01-05T07:00:00Z',
              'acted_at': '2026-01-05T07:30:00Z',
              'created_at': '2026-01-05T07:00:00Z',
              'updated_at': '2026-01-05T07:30:00Z',
              'deleted_at': null,
              'row_version': 1,
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows =
          await db.query('reminder_history');
      expect(rows, hasLength(1));
      expect(rows.single['reminder_id'], reminderId,
          reason: 'cloud reminder uuid resolves back to the local int id');
      expect(rows.single['status'], 'completed');
      expect(await eventsFor('reminder_history'), isEmpty);
    });
  });

  group('reward', () {
    setUp(setUpDb);

    RewardLocalDataSource dao() => RewardLocalDataSource(database: appDatabase);

    Reward reward({String userId = 'user-1'}) => Reward(
          userId: userId,
          type: 'coins',
          title: 'Workout xp bonus',
          amount: 50,
          icon: 'monetization_on',
          isClaimed: false,
          claimedAt: null,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );

    test('insert stamps uuid, version 1 and a CREATE event', () async {
      final int id = await dao().insert(reward());
      final Map<String, Object?> row = await rowById('reward', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      final List<Map<String, Object?>> events = await eventsFor('reward');
      expect(events.single['operation'], SyncOperation.create.name);
    });

    test('update preserves uuid and records base_version', () async {
      final int id = await dao().insert(reward());
      final String uuid = await uuidById('reward', id);

      await dao().update(
        reward().copyWith(
          id: id,
          isClaimed: true,
          claimedAt: DateTime.utc(2026, 1, 2),
        ),
      );

      final Map<String, Object?> row = await rowById('reward', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['is_claimed'], 1);
      final List<Map<String, Object?>> events = await eventsFor('reward');
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final int id = await dao().insert(reward());
      await dao().delete(id);
      expect((await rowById('reward', id))['deleted_at'], isNotNull);
      expect(await dao().getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('reward');
      expect(events.last['operation'], SyncOperation.delete.name);
    });

    test('remote apply maps claim state and never echoes', () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'user_rewards',
            recordId: 'rw-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'rw-uuid-1',
              'user_id': 'user-1',
              'type': 'coins',
              'title': 'Seven day streak',
              'amount': 100,
              'icon': 'star',
              'is_claimed': true,
              'claimed_at': '2026-01-03T10:00:00Z',
              'created_at': '2026-01-01T10:00:00Z',
              'updated_at': '2026-01-03T10:00:00Z',
              'deleted_at': null,
              'row_version': 1,
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query('reward');
      expect(rows, hasLength(1));
      expect(rows.single['uuid'], 'rw-uuid-1');
      expect(rows.single['is_claimed'], 1);
      expect(rows.single['type'], 'coins');
      expect(await eventsFor('reward'), isEmpty);
    });

    test('events are scoped per user', () async {
      await dao().insert(reward());
      await dao().insert(reward(userId: 'user-2'));
      final List<Map<String, Object?>> events = await eventsFor('reward');
      expect(events, hasLength(2));
    });
  });

  group('xp_history', () {
    setUp(setUpDb);

    XpHistoryLocalDataSource dao() =>
        XpHistoryLocalDataSource(database: appDatabase);

    XpHistory entry({String userId = 'user-1'}) => XpHistory(
          userId: userId,
          source: 'workout',
          reason: 'completed_session',
          xp: 20,
          totalXp: 20,
          metadata: '{"historyId":1}',
          createdAt: DateTime.utc(2026, 1, 1, 9),
        );

    test('insert stamps uuid, version 1 and a CREATE event', () async {
      final int id = await dao().insert(entry());
      final Map<String, Object?> row = await rowById('xp_history', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['source'], 'workout');
      final List<Map<String, Object?>> events = await eventsFor('xp_history');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
    });

    test('update preserves uuid and records base_version', () async {
      final int id = await dao().insert(entry());
      final String uuid = await uuidById('xp_history', id);

      await dao().update(entry().copyWith(id: id, xp: 25, totalXp: 25));

      final Map<String, Object?> row = await rowById('xp_history', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['xp'], 25);
      final List<Map<String, Object?>> events = await eventsFor('xp_history');
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final int id = await dao().insert(entry());
      await dao().delete(id);
      expect((await rowById('xp_history', id))['deleted_at'], isNotNull);
      expect(await dao().getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('xp_history');
      expect(events.last['operation'], SyncOperation.delete.name);
    });

    test('registry excludes the derived total_xp and the jsonb metadata',
        () async {
      final SyncTableMapping? mapping =
          SyncTableRegistry.byLocalTable('xp_history');
      expect(mapping, isNotNull);
      expect(mapping!.cloudTable, 'xp_history');
      expect(mapping.localToCloud.containsKey('total_xp'), isFalse,
          reason: 'total_xp is a derived running total (recomputable as SUM)');
      expect(mapping.localToCloud.containsKey('metadata'), isFalse,
          reason: 'cloud metadata is jsonb; text transport cannot round-trip');
      expect(mapping.localToCloud['source'], 'source');
      expect(mapping.localToCloud['xp'], 'xp');
    });

    test('remote apply writes ledger columns and never echoes', () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'xp_history',
            recordId: 'xp-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'xp-uuid-1',
              'user_id': 'user-1',
              'source': 'challenge',
              'reason': 'challenge_completed',
              'xp': 50,
              'created_at': '2026-01-04T09:00:00Z',
              'updated_at': '2026-01-04T09:00:00Z',
              'deleted_at': null,
              'row_version': 1,
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query('xp_history');
      expect(rows, hasLength(1));
      expect(rows.single['uuid'], 'xp-uuid-1');
      expect(rows.single['source'], 'challenge');
      expect(rows.single['xp'], 50);
      expect(await eventsFor('xp_history'), isEmpty);
    });
  });

  group('derived / server-authoritative data is never uploaded', () {
    setUp(setUpDb);

    test('daily_progress is a derived rollup: writes create no outbound event',
        () async {
      final DailyProgressLocalDataSource dao =
          DailyProgressLocalDataSource(database: appDatabase);
      await dao.upsert(
        DailyProgress(
          userId: 'user-1',
          progressDate: DateTime(2026, 1, 5),
          steps: 8000,
          waterMl: 2000,
          caloriesConsumed: 1800,
          caloriesBurned: 400,
          workoutMinutes: 45,
          sleepMinutes: 420,
          isGoalMet: true,
          createdAt: DateTime.utc(2026, 1, 5),
          updatedAt: DateTime.utc(2026, 1, 5),
        ),
      );
      await dao.delete((await dao.getByUserAndDate('user-1', DateTime(2026, 1, 5)))!.id!);
      expect(await db.query('daily_progress'), isEmpty);
      expect(await eventsFor('daily_progress'), isEmpty);
      expect(SyncTableRegistry.byLocalTable('daily_progress'), isNull,
          reason: 'recomputable rollup; not a sync source-of-truth');
    });

    test('streak is a derived cache: writes create no outbound event', () async {
      final StreakLocalDataSource dao = StreakLocalDataSource(database: appDatabase);
      final DateTime now = DateTime.utc(2026, 1, 5);
      await dao.upsert(
        Streak(
          userId: 'user-1',
          streakType: StreakType.workout,
          currentStreak: 5,
          longestStreak: 7,
          lastActiveDate: DateTime(2026, 1, 5),
          bestDate: DateTime(2026, 1, 3),
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(await eventsFor('streak'), isEmpty);
      expect(SyncTableRegistry.byLocalTable('streak'), isNull,
          reason: 'streak counters are recomputable from synced workout_history');
    });

    test('hybrid achievement/badge/challenge/milestone are not registered',
        () async {
      final DateTime now = DateTime.utc(2026, 1, 5);
      await AchievementLocalDataSource(database: appDatabase).insertAll(
        <Achievement>[
          Achievement(
            userId: 'user-1',
            name: 'First Workout',
            achievementType: 'first_workout',
            isUnlocked: true,
            unlockedAt: now,
            createdAt: now,
          ),
        ],
      );
      await BadgeLocalDataSource(database: appDatabase).insertAll(
        <Badge>[
          Badge(
            userId: 'user-1',
            badgeType: 'workouts_5',
            badgeName: 'Consistent',
            level: 1,
            progress: 5,
            target: 5,
            isEarned: true,
            earnedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      await ChallengeLocalDataSource(database: appDatabase).insert(
        Challenge(
          userId: 'user-1',
          title: 'Run 10 km',
          type: 'run_10km',
          description: 'Complete 10 km',
          difficulty: 'medium',
          target: 10,
          rewardXp: 50,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(await eventsFor('achievement'), isEmpty);
      expect(await eventsFor('badge'), isEmpty);
      expect(await eventsFor('challenge'), isEmpty);
      for (final String table in <String>[
        'achievement',
        'badge',
        'challenge',
        'milestone',
      ]) {
        expect(SyncTableRegistry.byLocalTable(table), isNull,
            reason: '$table mirrors server-authoritative master definitions; '
                'the client never uploads master changes');
      }
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

    SyncChange reminderChange(
      int cursorId, {
      String recordId = 'rem-uuid-1',
    }) =>
        SyncChange(
          cursorId: cursorId,
          cloudTable: 'reminders',
          recordId: recordId,
          operation: SyncOperation.create,
          payload: <String, Object?>{
            'id': recordId,
            'user_id': 'user-1',
            'title': 'Workout $cursorId',
            'time': '07:00',
            'reminder_type': 'workout',
            'schedule_type': 'daily',
            'is_enabled': true,
            'start_date': '2026-01-01',
            'created_at': '2026-01-01T06:00:00Z',
            'updated_at': '2026-01-01T06:00:00Z',
            'deleted_at': null,
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
            reminderChange(5, recordId: 'rem-uuid-1'),
            reminderChange(6, recordId: 'rem-uuid-2'),
          ],
        ),
        applier: applier,
      );
      final SyncState first = (await stateRepo.getByUserId('user-1'))!;
      expect(first.cursor, 6);
      expect(await db.query('reminder'), hasLength(2));

      // Second run only pulls cursor-7+ changes; 5/6 are never re-applied.
      await syncEngine.pull(
        userId: 'user-1',
        transport: _PullTransport(
          remoteChanges: <SyncChange>[
            reminderChange(5, recordId: 'rem-uuid-1'),
            reminderChange(6, recordId: 'rem-uuid-2'),
            reminderChange(7, recordId: 'rem-uuid-3'),
          ],
        ),
        applier: applier,
      );
      final SyncState second = (await stateRepo.getByUserId('user-1'))!;
      expect(second.cursor, 7);
      expect(await db.query('reminder'), hasLength(3));
    });

    test('a parent/child batch applies reminder before reminder_history',
        () async {
      await engine().pull(
        userId: 'user-1',
        transport: _PullTransport(
          remoteChanges: <SyncChange>[
            SyncChange(
              cursorId: 2,
              cloudTable: 'reminder_history',
              recordId: 'rh-uuid-1',
              operation: SyncOperation.create,
              payload: <String, Object?>{
                'id': 'rh-uuid-1',
                'user_id': 'user-1',
                'reminder_id': 'rem-uuid-1',
                'status': 'missed',
                'scheduled_for': '2026-01-01T07:00:00Z',
                'created_at': '2026-01-01T07:00:00Z',
                'updated_at': '2026-01-01T07:00:00Z',
                'deleted_at': null,
                'row_version': 1,
              },
            ),
            reminderChange(1, recordId: 'rem-uuid-1'),
          ],
        ),
        applier: applier,
      );

      final List<Map<String, Object?>> history =
          await db.query('reminder_history');
      expect(history, hasLength(1));
      final List<Map<String, Object?>> reminders =
          await db.query('reminder');
      expect(reminders, hasLength(1));
      expect(history.single['reminder_id'], reminders.single['id'],
          reason: 'parent uuid resolved to the local int id');
    });

    test('duplicate pending outbox events are merged into one', () async {
      final SyncEngine syncEngine = engine();
      await syncEngine.track(
        userId: 'user-1',
        entity: 'reminder',
        entityId: 'rem-1',
        operation: SyncOperation.update,
        baseVersion: 1,
      );
      final String? firstUuid = await eventRepo
          .getPendingByUserId('user-1')
          .then((List<SyncEvent> e) => e.single.eventUuid);
      await syncEngine.track(
        userId: 'user-1',
        entity: 'reminder',
        entityId: 'rem-1',
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
        entity: 'reward',
        entityId: 'rw-1',
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
  });
}
