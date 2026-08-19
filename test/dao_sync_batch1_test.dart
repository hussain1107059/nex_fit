import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/app_settings_local_data_source.dart';
import 'package:nexfit/data/datasources/local/fitness_goal_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/user_profile_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_exercise_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_history_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_contracts.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/data/services/sync/sync_table_registry.dart';
import 'package:nexfit/domain/entities/app_settings.dart';
import 'package:nexfit/domain/entities/common_enums.dart';
import 'package:nexfit/domain/entities/fitness_goal.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/user_profile.dart';
import 'package:nexfit/domain/entities/workout.dart';
import 'package:nexfit/domain/entities/workout_exercise.dart';
import 'package:nexfit/domain/entities/workout_history.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// PROMPT 11 Batch 1 DAO migration tests.
///
/// For every migrated table (fitness_goal, workout, workout_exercise,
/// workout_history, user_profile, app_settings) verifies:
///  - local insert/update/delete create the row + outbox event atomically,
///  - uuid is generated once on insert and preserved on update,
///  - row_version increments (update/delete) and is stamped 1 on insert,
///  - delete soft-deletes (deleted_at) instead of destroying the row,
///  - a failed mutation rolls back both the row and its event,
///  - remote apply updates the local row WITHOUT creating an outbound event,
///  - events and rows are scoped per user.

final RegExp _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Future<String> _databasePath() async {  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

String _iso(DateTime value) => value.toUtc().toIso8601String();

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
    );
  }

  tearDown(() async {
    SyncEventRecorder.setEnabled(false);
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

  Future<int> insertExercise(String uuid) async {
    return db.insert('exercise', <String, Object?>{
      'user_id': 'user-1',
      'name': 'Push-up',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'uuid': uuid,
    });
  }

  group('fitness_goal', () {
    setUp(setUpDb);

    FitnessGoalLocalDataSource dao() =>
        FitnessGoalLocalDataSource(database: appDatabase);

    FitnessGoal goal(String? userId) => FitnessGoal(
          userId: userId,
          title: 'Lose 5kg',
          goalType: GoalType.weightLoss,
          currentValue: 0,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );

    test('insert generates uuid, stamps version 1 and a CREATE event', () async {
      final int id = await dao().insert(goal('user-1'));
      final Map<String, Object?> row = await rowById('fitness_goal', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['created_at'], isNotNull);
      expect(row['updated_at'], isNotNull);
      expect(row['user_id'], 'user-1');

      final List<Map<String, Object?>> events = await eventsFor('fitness_goal');
      expect(events, hasLength(1));
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
      expect(events.single['user_id'], 'user-1');
      expect(events.single['base_version'], 0);
      expect(events.single['status'], SyncStatus.pending.name);
      expect(events.single['device_id'], 'device-1');
      expect(events.single['event_uuid'], matches(_uuidRegex));
    });

    test('update preserves uuid, bumps version and records base_version', () async {
      final FitnessGoalLocalDataSource source = dao();
      final int id = await source.insert(goal('user-1'));
      final String uuid = (await rowById('fitness_goal', id))['uuid'] as String;

      await source.update(
        goal('user-1').copyWith(id: id, currentValue: 2.5),
      );

      final Map<String, Object?> row = await rowById('fitness_goal', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['current_value'], 2.5);
      final List<Map<String, Object?>> events = await eventsFor('fitness_goal');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes, bumps version and records a DELETE event', () async {
      final FitnessGoalLocalDataSource source = dao();
      final int id = await source.insert(goal('user-1'));
      await source.delete(id);

      final Map<String, Object?> row = await rowById('fitness_goal', id);
      expect(row['deleted_at'], isNotNull);
      expect(row['row_version'], 2);
      expect(await source.getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('fitness_goal');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('a failing insert rolls back both the row and its event', () async {
      await expectLater(
        dao().insert(goal('ghost-user')),
        throwsA(anything),
      );
      expect(
        await db.query(
          'fitness_goal',
          where: 'user_id = ?',
          whereArgs: <Object?>['ghost-user'],
        ),
        isEmpty,
      );
      expect(await eventsFor('fitness_goal'), isEmpty);
    });

    test('remote apply updates the local row and creates no outbound event',
        () async {
      final FitnessGoalLocalDataSource source = dao();
      final int id = await source.insert(goal('user-1'));
      final String uuid = (await rowById('fitness_goal', id))['uuid'] as String;

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'fitness_goals',
            recordId: uuid,
            operation: SyncOperation.update,
            payload: <String, Object?>{
              'id': uuid,
              'user_id': 'user-1',
              'title': 'Lose 10kg',
              'goal_type': GoalType.weightLoss.name,
              'status': GoalStatus.active.name,
              'current_value': 1.0,
              'row_version': 7,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 2, 1)),
            },
          ),
        );
      });

      final Map<String, Object?> row = await rowById('fitness_goal', id);
      expect(row['title'], 'Lose 10kg');
      expect(row['row_version'], 7);
      expect(row['updated_at'], DateTime.utc(2026, 2, 1).millisecondsSinceEpoch);
      // Only the original CREATE event; the remote apply enqueued nothing.
      expect(await eventsFor('fitness_goal'), hasLength(1));
    });

    test('user isolation keeps events and rows scoped', () async {
      await dao().insert(goal('user-1'));
      await dao().insert(goal('user-2'));
      final List<Map<String, Object?>> events = await eventsFor('fitness_goal');
      expect(events.map((Map<String, Object?> e) => e['user_id']),
          containsAll(<Object?>['user-1', 'user-2']));
      expect(
        await db.query('fitness_goal', where: 'user_id = ?', whereArgs: <Object?>['user-1']),
        hasLength(1),
      );
      expect(
        await db.query('fitness_goal', where: 'user_id = ?', whereArgs: <Object?>['user-2']),
        hasLength(1),
      );
    });
  });

  group('workout', () {
    setUp(setUpDb);

    WorkoutLocalDataSource dao() => WorkoutLocalDataSource(database: appDatabase);

    Workout workout(String userId) => Workout(
          userId: userId,
          name: 'Morning Cardio',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );

    test('insert generates uuid, stamps version 1 and a CREATE event', () async {
      final int id = await dao().insert(workout('user-1'));
      final Map<String, Object?> row = await rowById('workout', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['user_id'], 'user-1');
      final List<Map<String, Object?>> events = await eventsFor('workout');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
    });

    test('setFavorite is an UPDATE that bumps version and records an event',
        () async {
      final WorkoutLocalDataSource source = dao();
      final int id = await source.insert(workout('user-1'));
      final String uuid = (await rowById('workout', id))['uuid'] as String;

      await source.setFavorite(id, true);

      final Map<String, Object?> row = await rowById('workout', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['is_favorite'], 1);
      final List<Map<String, Object?>> events = await eventsFor('workout');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete tombstones the workout AND its children with DELETE events',
        () async {
      final WorkoutLocalDataSource source = dao();
      final int id = await source.insert(workout('user-1'));
      final int exerciseId = await insertExercise('exercise-uuid-1');
      final int childId = await WorkoutExerciseLocalDataSource(
        database: appDatabase,
      ).insert(WorkoutExercise(workoutId: id, exerciseId: exerciseId));

      await source.delete(id);

      final Map<String, Object?> workoutRow = await rowById('workout', id);
      expect(workoutRow['deleted_at'], isNotNull);
      final Map<String, Object?> childRow = await rowById('workout_exercise', childId);
      expect(childRow['deleted_at'], isNotNull);
      final List<Map<String, Object?>> workoutEvents =
          await eventsFor('workout');
      expect(workoutEvents.last['operation'], SyncOperation.delete.name);
      final List<Map<String, Object?>> childEvents =
          await eventsFor('workout_exercise');
      expect(childEvents.last['operation'], SyncOperation.delete.name);
    });

    test('a failing insert rolls back both the row and its event', () async {
      await expectLater(
        dao().insert(workout('ghost-user')),
        throwsA(anything),
      );
      expect(await db.query('workout'), isEmpty);
      expect(await eventsFor('workout'), isEmpty);
    });

    test('remote apply updates the local row and creates no outbound event',
        () async {
      final WorkoutLocalDataSource source = dao();
      final int id = await source.insert(workout('user-1'));
      final String uuid = (await rowById('workout', id))['uuid'] as String;

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'workouts',
            recordId: uuid,
            operation: SyncOperation.update,
            payload: <String, Object?>{
              'id': uuid,
              'user_id': 'user-1',
              'name': 'Evening Cardio',
              'is_favorite': true,
              'row_version': 3,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 2, 1)),
            },
          ),
        );
      });

      final Map<String, Object?> row = await rowById('workout', id);
      expect(row['name'], 'Evening Cardio');
      expect(row['is_favorite'], 1);
      expect(row['row_version'], 3);
      expect(await eventsFor('workout'), hasLength(1));
    });
  });

  group('workout_exercise', () {
    setUp(setUpDb);

    WorkoutExerciseLocalDataSource dao() =>
        WorkoutExerciseLocalDataSource(database: appDatabase);

    test('insert resolves user_id from the parent workout and records a CREATE event',
        () async {
      final int exerciseId = await insertExercise('exercise-uuid-1');
      final int workoutId = await WorkoutLocalDataSource(
        database: appDatabase,
      ).insert(
        Workout(
          userId: 'user-1',
          name: 'Legs',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final int id = await dao().insert(
        WorkoutExercise(workoutId: workoutId, exerciseId: exerciseId, sets: 3),
      );
      final Map<String, Object?> row = await rowById('workout_exercise', id);
      expect(row['user_id'], 'user-1');
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      final List<Map<String, Object?>> events = await eventsFor('workout_exercise');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['user_id'], 'user-1');
    });
test('update preserves uuid, bumps version and records base_version',
        () async {
      final int exerciseId = await insertExercise('exercise-uuid-1');
      final int workoutId = await WorkoutLocalDataSource(
        database: appDatabase,
      ).insert(
        Workout(
          userId: 'user-1',
          name: 'Legs',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final WorkoutExerciseLocalDataSource source = dao();
      final int id = await source.insert(
        WorkoutExercise(workoutId: workoutId, exerciseId: exerciseId),
      );
      final String uuid = (await rowById('workout_exercise', id))['uuid']
          as String;

      await source.update(
        WorkoutExercise(
          id: id,
          workoutId: workoutId,
          exerciseId: exerciseId,
          reps: 12,
        ),
      );

      final Map<String, Object?> row = await rowById('workout_exercise', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['reps'], 12);
      final List<Map<String, Object?>> events = await eventsFor('workout_exercise');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final int exerciseId = await insertExercise('exercise-uuid-1');
      final int workoutId = await WorkoutLocalDataSource(
        database: appDatabase,
      ).insert(
        Workout(
          userId: 'user-1',
          name: 'Legs',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final WorkoutExerciseLocalDataSource source = dao();
      final int id = await source.insert(
        WorkoutExercise(workoutId: workoutId, exerciseId: exerciseId),
      );
      await source.delete(id);
      final Map<String, Object?> row = await rowById('workout_exercise', id);
      expect(row['deleted_at'], isNotNull);
      expect(row['row_version'], 2);
      final List<Map<String, Object?>> events = await eventsFor('workout_exercise');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('a failing insert (missing parent) rolls back row and event', () async {
      await expectLater(
        dao().insert(WorkoutExercise(workoutId: 9999, exerciseId: 1)),
        throwsA(anything),
      );
      expect(await db.query('workout_exercise'), isEmpty);
      expect(await eventsFor('workout_exercise'), isEmpty);
    });

    test('remote apply resolves cloud uuids to local ids and records no event',
        () async {
      final int exerciseId = await insertExercise('exercise-uuid-1');
      final int workoutId = await WorkoutLocalDataSource(
        database: appDatabase,
      ).insert(
        Workout(
          userId: 'user-1',
          name: 'Legs',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final String workoutUuid = (await rowById('workout', workoutId))['uuid'] as String;
      expect(exerciseId, greaterThan(0));

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'workout_exercises',
            recordId: 'child-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'child-uuid-1',
              'user_id': 'user-1',
              'workout_id': workoutUuid,
              'exercise_id': 'exercise-uuid-1',
              'sets': 4,
              'reps': 8,
              'sort_order': 1,
              'row_version': 1,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 1, 1)),
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query(
        'workout_exercise',
        where: 'uuid = ?',
        whereArgs: <Object?>['child-uuid-1'],
      );
      expect(rows, hasLength(1));
      final Map<String, Object?> row = rows.single;
      expect(row['workout_id'], workoutId);
      expect(row['exercise_id'], exerciseId);
      expect(row['user_id'], 'user-1');
      expect(row['row_version'], 1);
      expect(await eventsFor('workout_exercise'), isEmpty);
    });

    test('registry maps workout_exercise foreign keys for uuid resolution',
        () {
      final SyncTableMapping? mapping =
          SyncTableRegistry.byLocalTable('workout_exercise');
      expect(mapping, isNotNull);
      expect(mapping!.cloudTable, 'workout_exercises');
      expect(mapping.cloudForeignKeys['workout_id'], 'workout');
      expect(mapping.cloudForeignKeys['exercise_id'], 'exercise');
    });
  });

  group('workout_history', () {
    setUp(setUpDb);

    WorkoutHistoryLocalDataSource dao() =>
        WorkoutHistoryLocalDataSource(database: appDatabase);

    WorkoutHistory history() => WorkoutHistory(
          userId: 'user-1',
          startedAt: DateTime.utc(2026, 1, 1, 10),
          endedAt: DateTime.utc(2026, 1, 1, 10, 45),
          durationMinutes: 45,
          caloriesBurn: 320,
          isCompleted: true,
          createdAt: DateTime.utc(2026, 1, 1),
        );

    test('insert generates uuid, stamps version 1 and a CREATE event', () async {
      final int id = await dao().insert(history());
      final Map<String, Object?> row = await rowById('workout_history', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['created_at'], isNotNull);
      expect(row['updated_at'], isNotNull);
      final List<Map<String, Object?>> events = await eventsFor('workout_history');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
    });

    test('update preserves uuid, bumps version and records base_version',
        () async {
      final WorkoutHistoryLocalDataSource source = dao();
      final int id = await source.insert(history());
      final String uuid = (await rowById('workout_history', id))['uuid'] as String;

      await source.update(history().copyWith(id: id, caloriesBurn: 400));

      final Map<String, Object?> row = await rowById('workout_history', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      final List<Map<String, Object?>> events = await eventsFor('workout_history');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final WorkoutHistoryLocalDataSource source = dao();
      final int id = await source.insert(history());
      await source.delete(id);
      final Map<String, Object?> row = await rowById('workout_history', id);
      expect(row['deleted_at'], isNotNull);
      expect(row['row_version'], 2);
      expect(await source.getById(id), isNull);
      expect(await source.getCompleted('user-1'), isEmpty);
      final List<Map<String, Object?>> events = await eventsFor('workout_history');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('a failing insert rolls back both the row and its event', () async {
      await expectLater(
        dao().insert(history().copyWith(userId: 'ghost-user')),
        throwsA(anything),
      );
      expect(await db.query('workout_history'), isEmpty);
      expect(await eventsFor('workout_history'), isEmpty);
    });

    test('remote apply updates the local row and creates no outbound event',
        () async {
      final WorkoutHistoryLocalDataSource source = dao();
      final int id = await source.insert(history());
      final String uuid = (await rowById('workout_history', id))['uuid'] as String;

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'workout_history',
            recordId: uuid,
            operation: SyncOperation.update,
            payload: <String, Object?>{
              'id': uuid,
              'user_id': 'user-1',
              'started_at': _iso(DateTime.utc(2026, 1, 1, 10)),
              'ended_at': _iso(DateTime.utc(2026, 1, 1, 11)),
              'is_completed': true,
              'duration_minutes': 60,
              'row_version': 4,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 2, 1)),
            },
          ),
        );
      });

      final Map<String, Object?> row = await rowById('workout_history', id);
      expect(row['duration_minutes'], 60);
      expect(row['row_version'], 4);
      expect(await eventsFor('workout_history'), hasLength(1));
    });
  });

  group('user_profile', () {
    setUp(setUpDb);

    UserProfileLocalDataSource dao() =>
        UserProfileLocalDataSource(database: appDatabase);

    UserProfile profile() => UserProfile(
          userId: 'user-1',
          heightCm: 175,
          weightKg: 80,
          updatedAt: DateTime.utc(2026, 1, 1),
        );

    test('upsert create uses user_id as cloud id and records a CREATE event',
        () async {
      await dao().upsert(profile());
      final List<Map<String, Object?>> rows = await db.query('user_profile');
      expect(rows, hasLength(1));
      expect(rows.single['uuid'], 'user-1');
      expect(rows.single['row_version'], 1);
      expect(rows.single['created_at'], isNotNull);
      final List<Map<String, Object?>> events = await eventsFor('user_profile');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], 'user-1');
      expect(events.single['base_version'], 0);
    });

    test('upsert update preserves uuid, bumps version and records base_version',
        () async {
      final UserProfileLocalDataSource source = dao();
      await source.upsert(profile());
      await source.upsert(
        profile().copyWith(weightKg: 78, updatedAt: DateTime.utc(2026, 2, 1)),
      );
      final List<Map<String, Object?>> rows = await db.query('user_profile');
      expect(rows.single['uuid'], 'user-1');
      expect(rows.single['row_version'], 2);
      expect(rows.single['weight_kg'], 78);
      final List<Map<String, Object?>> events = await eventsFor('user_profile');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final UserProfileLocalDataSource source = dao();
      await source.upsert(profile());
      await source.delete('user-1');
      final List<Map<String, Object?>> rows = await db.query('user_profile');
      expect(rows.single['deleted_at'], isNotNull);
      expect(rows.single['row_version'], 2);
      expect(await source.getById('user-1'), isNull);
      final List<Map<String, Object?>> events = await eventsFor('user_profile');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('a failing upsert (unknown user) rolls back row and event', () async {
      await expectLater(
        dao().upsert(profile().copyWith(userId: 'ghost-user')),
        throwsA(anything),
      );
      expect(await db.query('user_profile'), isEmpty);
      expect(await eventsFor('user_profile'), isEmpty);
    });

    test('remote apply updates the local row and creates no outbound event',
        () async {
      final UserProfileLocalDataSource source = dao();
      await source.upsert(profile());

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'profiles',
            recordId: 'user-1',
            operation: SyncOperation.update,
            payload: <String, Object?>{
              'id': 'user-1',
              'height_cm': 178.0,
              'weight_kg': 79.0,
              'row_version': 6,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 2, 1)),
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query('user_profile');
      expect(rows.single['height_cm'], 178.0);
      expect(rows.single['row_version'], 6);
      expect(await eventsFor('user_profile'), hasLength(1));
    });
  });

  group('app_settings', () {
    setUp(setUpDb);

    AppSettingsLocalDataSource dao() =>
        AppSettingsLocalDataSource(database: appDatabase);

    AppSettings settings() => AppSettings(
          userId: 'user-1',
          theme: 'dark',
          units: Units.metric,
          updatedAt: DateTime.utc(2026, 1, 1),
        );

    test('upsert create uses user_id as cloud id and records a CREATE event',
        () async {
      await dao().upsert(settings());
      final List<Map<String, Object?>> rows = await db.query('app_settings');
      expect(rows, hasLength(1));
      expect(rows.single['uuid'], 'user-1');
      expect(rows.single['row_version'], 1);
      expect(rows.single['created_at'], isNotNull);
      final List<Map<String, Object?>> events = await eventsFor('app_settings');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], 'user-1');
    });

    test('upsert update preserves uuid, bumps version and records base_version',
        () async {
      final AppSettingsLocalDataSource source = dao();
      await source.upsert(settings());
      await source.upsert(
        settings().copyWith(theme: 'light', updatedAt: DateTime.utc(2026, 2, 1)),
      );
      final List<Map<String, Object?>> rows = await db.query('app_settings');
      expect(rows.single['uuid'], 'user-1');
      expect(rows.single['row_version'], 2);
      final List<Map<String, Object?>> events = await eventsFor('app_settings');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final AppSettingsLocalDataSource source = dao();
      await source.upsert(settings());
      await source.delete('user-1');
      final List<Map<String, Object?>> rows = await db.query('app_settings');
      expect(rows.single['deleted_at'], isNotNull);
      expect(rows.single['row_version'], 2);
      expect(await source.getByUserId('user-1'), isNull);
      final List<Map<String, Object?>> events = await eventsFor('app_settings');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('a failing upsert (unknown user) rolls back row and event', () async {
      await expectLater(
        dao().upsert(settings().copyWith(userId: 'ghost-user')),
        throwsA(anything),
      );
      expect(await db.query('app_settings'), isEmpty);
      expect(await eventsFor('app_settings'), isEmpty);
    });

    test('remote apply updates the local row and creates no outbound event',
        () async {
      final AppSettingsLocalDataSource source = dao();
      await source.upsert(settings());

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'user_settings',
            recordId: 'user-1',
            operation: SyncOperation.update,
            payload: <String, Object?>{
              'id': 'user-1',
              'user_id': 'user-1',
              'theme_mode': 'light',
              'units': 'imperial',
              'row_version': 5,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 2, 1)),
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query('app_settings');
      expect(rows.single['theme_mode'], 'light');
      expect(rows.single['units'], 'imperial');
      expect(rows.single['row_version'], 5);
      expect(await eventsFor('app_settings'), hasLength(1));
    });

    test('silent upsert (telemetry) keeps version and records no event', () async {
      final AppSettingsLocalDataSource source = dao();
      await source.upsert(settings());
      await source.upsert(
        settings().copyWith(
          lastSyncAt: DateTime.utc(2026, 3, 1),
          updatedAt: DateTime.utc(2026, 3, 1),
        ),
        trackSync: false,
      );
      final List<Map<String, Object?>> rows = await db.query('app_settings');
      expect(rows.single['row_version'], 1);
      expect(rows.single['last_sync_at'], isNotNull);
      final List<Map<String, Object?>> events =
          await eventsFor('app_settings');
      expect(events, hasLength(1));
      expect(events.single['operation'], SyncOperation.create.name);
    });
  });
}
