import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/errors/app_exception.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/exercise_history_local_data_source.dart';
import 'package:nexfit/data/datasources/local/exercise_local_data_source.dart';
import 'package:nexfit/data/datasources/local/food_item_local_data_source.dart';
import 'package:nexfit/data/datasources/local/food_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/meal_item_local_data_source.dart';
import 'package:nexfit/data/datasources/local/meal_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_history_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_contracts.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/data/services/sync/sync_table_registry.dart';
import 'package:nexfit/domain/entities/exercise_history.dart';
import 'package:nexfit/domain/entities/food_log.dart';
import 'package:nexfit/domain/entities/meal.dart';
import 'package:nexfit/domain/entities/meal_item.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/workout_history.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 12 Batch 2 DAO migration tests.
///
/// For every migrated table (exercise_history, exercise_favorite, food_log,
/// food_favorite, meal, meal_item) verifies:
///  - local insert/update/delete create the row + outbox event atomically,
///  - uuid is generated once on insert and preserved on update,
///  - row_version increments (update/delete) and is stamped 1 on insert,
///  - delete soft-deletes (deleted_at) instead of destroying the row,
///  - a failed mutation rolls back both the row and its event,
///  - remote apply updates the local row WITHOUT creating an outbound event,
///  - events and rows are scoped per user,
///  - favorites are validated against the authenticated user,
///  - meal/meal_item and exercise_history parents apply before children,
///  - a large local nutrition dataset is inserted via batched operations.

final RegExp _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
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

  Future<int> insertExercise(String uuid) async {
    return db.insert('exercise', <String, Object?>{
      'user_id': 'user-1',
      'name': 'Push-up',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'uuid': uuid,
    });
  }

  Future<int> insertFood(String uuid, {String userId = 'user-1'}) async {
    return db.insert('food_item', <String, Object?>{
      'user_id': userId,
      'name': 'Rice',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'uuid': uuid,
    });
  }

  Future<int> insertWorkoutHistory(String userId) async {
    return WorkoutHistoryLocalDataSource(database: appDatabase).insert(
      WorkoutHistory(
        userId: userId,
        startedAt: DateTime.utc(2026, 1, 1, 10),
        endedAt: DateTime.utc(2026, 1, 1, 11),
        durationMinutes: 60,
        caloriesBurn: 300,
        isCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  Future<int> insertMeal(String userId) async {
    return MealLocalDataSource(database: appDatabase).insert(
      Meal(
        userId: userId,
        name: 'Chicken Bowl',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  group('exercise_history', () {
    setUp(setUpDb);

    ExerciseHistoryLocalDataSource dao() =>
        ExerciseHistoryLocalDataSource(database: appDatabase);

    ExerciseHistory history({required int workoutHistoryId, int? exerciseId}) =>
        ExerciseHistory(
          workoutHistoryId: workoutHistoryId,
          exerciseId: exerciseId,
          sets: 3,
          reps: 12,
          weightKg: 40,
        );

    test('insert resolves user_id from parent and stamps a CREATE event',
        () async {
      final int whId = await insertWorkoutHistory('user-1');
      final int id = await dao().insert(history(workoutHistoryId: whId));
      final Map<String, Object?> row = await rowById('exercise_history', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['user_id'], 'user-1');
      expect(row['created_at'], isNotNull);
      expect(row['updated_at'], isNotNull);
      final List<Map<String, Object?>> events = await eventsFor('exercise_history');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['user_id'], 'user-1');
      expect(events.single['entity_id'], '$id');
    });

    test('update preserves uuid, bumps version and records base_version',
        () async {
      final int whId = await insertWorkoutHistory('user-1');
      final int exerciseId = await insertExercise('exercise-uuid-1');
      final ExerciseHistoryLocalDataSource source = dao();
      final int id = await source.insert(
        history(workoutHistoryId: whId, exerciseId: exerciseId),
      );
      final String uuid = await uuidById('exercise_history', id);

      await source.update(
        ExerciseHistory(
          id: id,
          workoutHistoryId: whId,
          exerciseId: exerciseId,
          sets: 4,
          reps: 10,
        ),
      );

      final Map<String, Object?> row = await rowById('exercise_history', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['sets'], 4);
      final List<Map<String, Object?>> events = await eventsFor('exercise_history');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final int whId = await insertWorkoutHistory('user-1');
      final ExerciseHistoryLocalDataSource source = dao();
      final int id = await source.insert(history(workoutHistoryId: whId));
      await source.delete(id);
      final Map<String, Object?> row = await rowById('exercise_history', id);
      expect(row['deleted_at'], isNotNull);
      expect(row['row_version'], 2);
      expect(await source.getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('exercise_history');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('a failing insert (missing parent) rolls back row and event', () async {
      await expectLater(
        dao().insert(history(workoutHistoryId: 9999)),
        throwsA(anything),
      );
      expect(await db.query('exercise_history'), isEmpty);
      expect(await eventsFor('exercise_history'), isEmpty);
    });

    test('remote apply resolves uuids and creates no outbound event', () async {
      final int whId = await insertWorkoutHistory('user-1');
      final int exerciseId = await insertExercise('exercise-uuid-1');
      final String whUuid = await uuidById('workout_history', whId);

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'exercise_history',
            recordId: 'eh-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'eh-uuid-1',
              'user_id': 'user-1',
              'workout_history_id': whUuid,
              'exercise_id': 'exercise-uuid-1',
              'sets': 5,
              'reps': 8,
              'weight_kg': 50,
              'row_version': 1,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 1, 1)),
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query(
        'exercise_history',
        where: 'uuid = ?',
        whereArgs: <Object?>['eh-uuid-1'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['workout_history_id'], whId);
      expect(rows.single['exercise_id'], exerciseId);
      expect(rows.single['row_version'], 1);
      expect(await eventsFor('exercise_history'), isEmpty);
    });

    test('events are scoped to the owning user', () async {
      final int wh1 = await insertWorkoutHistory('user-1');
      final int wh2 = await insertWorkoutHistory('user-2');
      await dao().insert(history(workoutHistoryId: wh1));
      await dao().insert(history(workoutHistoryId: wh2));
      final List<Map<String, Object?>> events = await eventsFor('exercise_history');
      expect(
        events.map((Map<String, Object?> e) => e['user_id']),
        containsAll(<Object?>['user-1', 'user-2']),
      );
    });
  });

  group('exercise_favorite', () {
    setUp(setUpDb);

    ExerciseLocalDataSource dao() =>
        ExerciseLocalDataSource(database: appDatabase);

    test('addFavorite generates uuid, stamps version 1 and a CREATE event',
        () async {
      final int exerciseId = await insertExercise('exercise-uuid-1');
      await dao().addFavorite('user-1', exerciseId);
      final List<Map<String, Object?>> rows = await db.query(
        'exercise_favorite',
        where: 'user_id = ?',
        whereArgs: <Object?>['user-1'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['uuid'], matches(_uuidRegex));
      expect(rows.single['row_version'], 1);
      expect(rows.single['exercise_id'], exerciseId);
      final List<Map<String, Object?>> events = await eventsFor('exercise_favorite');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], rows.single['uuid'] as String);
      expect(events.single['user_id'], 'user-1');
    });

    test('removeFavorite soft-deletes and records a DELETE event', () async {
      final ExerciseLocalDataSource source = dao();
      final int exerciseId = await insertExercise('exercise-uuid-1');
      await source.addFavorite('user-1', exerciseId);
      final String uuid = (await db.query(
        'exercise_favorite',
        where: 'user_id = ?',
        whereArgs: <Object?>['user-1'],
      )).single['uuid'] as String;

      await source.removeFavorite('user-1', exerciseId);

      final List<Map<String, Object?>> rows = await db.query('exercise_favorite');
      expect(rows.single['deleted_at'], isNotNull);
      expect(rows.single['row_version'], 2);
      expect(await source.getFavoriteIds('user-1'), isEmpty);
      final List<Map<String, Object?>> events = await eventsFor('exercise_favorite');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['entity_id'], uuid);
      expect(events.last['base_version'], 1);
    });

    test('re-adding a removed favorite resurrects it with an UPDATE event',
        () async {
      final ExerciseLocalDataSource source = dao();
      final int exerciseId = await insertExercise('exercise-uuid-1');
      await source.addFavorite('user-1', exerciseId);
      await source.removeFavorite('user-1', exerciseId);
      await source.addFavorite('user-1', exerciseId);

      final List<Map<String, Object?>> rows = await db.query('exercise_favorite');
      expect(rows.single['deleted_at'], isNull);
      expect(rows.single['row_version'], 3);
      expect(await source.getFavoriteIds('user-1'), <int>{exerciseId});
      final List<Map<String, Object?>> events = await eventsFor('exercise_favorite');
      expect(events, hasLength(3));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 2);
    });

    test('duplicate addFavorite is a no-op without a second event', () async {
      final ExerciseLocalDataSource source = dao();
      final int exerciseId = await insertExercise('exercise-uuid-1');
      await source.addFavorite('user-1', exerciseId);
      await source.addFavorite('user-1', exerciseId);
      expect(await source.getFavoriteIds('user-1'), <int>{exerciseId});
      expect(await eventsFor('exercise_favorite'), hasLength(1));
    });

    test('ownership: a different user than the authenticated one is rejected',
        () async {
      final ExerciseLocalDataSource source = dao();
      await expectLater(
        () => source.addFavorite('user-2', 7),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        () => source.removeFavorite('user-2', 7),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('exercise_favorite'), isEmpty);
      expect(await eventsFor('exercise_favorite'), isEmpty);
    });

    test('remote apply creates the favorite row and records no event', () async {
      final int exerciseId = await insertExercise('exercise-uuid-1');

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'exercise_favorites',
            recordId: 'fav-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'fav-uuid-1',
              'user_id': 'user-1',
              'exercise_id': 'exercise-uuid-1',
              'row_version': 1,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 1, 1)),
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query('exercise_favorite');
      expect(rows, hasLength(1));
      expect(rows.single['uuid'], 'fav-uuid-1');
      expect(rows.single['exercise_id'], exerciseId);
      expect(rows.single['user_id'], 'user-1');
      expect(await eventsFor('exercise_favorite'), isEmpty);
    });

    test('registry maps exercise_favorite with its foreign key', () {
      final SyncTableMapping? mapping =
          SyncTableRegistry.byLocalTable('exercise_favorite');
      expect(mapping, isNotNull);
      expect(mapping!.cloudTable, 'exercise_favorites');
      expect(mapping.localKeyColumn, 'uuid');
      expect(mapping.cloudForeignKeys['exercise_id'], 'exercise');
    });
  });

  group('food_log', () {
    setUp(setUpDb);

    FoodLogLocalDataSource dao() => FoodLogLocalDataSource(database: appDatabase);

    FoodLog log({String userId = 'user-1', DateTime? loggedAt}) => FoodLog(
          userId: userId,
          quantity: 1,
          calories: 200,
          protein: 5,
          carbs: 40,
          fat: 1,
          loggedAt: loggedAt ?? DateTime.utc(2026, 1, 1, 8),
          createdAt: DateTime.utc(2026, 1, 1),
        );

    test('insert generates uuid, stamps version 1 and a CREATE event', () async {
      final int id = await dao().insert(log());
      final Map<String, Object?> row = await rowById('food_log', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['user_id'], 'user-1');
      expect(row['created_at'], isNotNull);
      expect(row['updated_at'], isNotNull);
      final List<Map<String, Object?>> events = await eventsFor('food_log');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
    });

    test('update preserves uuid, bumps version and records base_version',
        () async {
      final FoodLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      final String uuid = await uuidById('food_log', id);

      await source.update(log().copyWith(id: id, calories: 300));

      final Map<String, Object?> row = await rowById('food_log', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['calories'], 300);
      final List<Map<String, Object?>> events = await eventsFor('food_log');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final FoodLogLocalDataSource source = dao();
      final int id = await source.insert(log());
      await source.delete(id);
      final Map<String, Object?> row = await rowById('food_log', id);
      expect(row['deleted_at'], isNotNull);
      expect(row['row_version'], 2);
      expect(await source.getById(id), isNull);
      final List<Map<String, Object?>> events = await eventsFor('food_log');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(dao().insert(log(userId: 'ghost-user')), throwsA(anything));
      expect(
        await db.query(
          'food_log',
          where: 'user_id = ?',
          whereArgs: <Object?>['ghost-user'],
        ),
        isEmpty,
      );
      expect(await eventsFor('food_log'), isEmpty);
    });

    test('remote apply uses the cloud food_id name and records no event',
        () async {
      final int foodId = await insertFood('food-uuid-1');
      final int mealId = await insertMeal('user-1');
      final String mealUuid = await uuidById('meal', mealId);
      expect(foodId, greaterThan(0));

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'food_logs',
            recordId: 'fl-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'fl-uuid-1',
              'user_id': 'user-1',
              'food_id': 'food-uuid-1',
              'meal_id': mealUuid,
              'quantity': 2,
              'serving_size': 'plate',
              'calories': 400,
              'logged_at': _iso(DateTime.utc(2026, 1, 1, 8)),
              'row_version': 1,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 1, 1)),
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query(
        'food_log',
        where: 'uuid = ?',
        whereArgs: <Object?>['fl-uuid-1'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['food_item_id'], foodId);
      expect(rows.single['meal_id'], mealId);
      expect(rows.single['row_version'], 1);
      expect(await eventsFor('food_log'), isEmpty);
    });

    test('a large local dataset is inserted via batched operations', () async {
      const int count = 2000;
      final FoodLogLocalDataSource source = dao();
      final List<FoodLog> logs = <FoodLog>[
        for (int i = 0; i < count; i++)
          log(loggedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i))),
      ];
      await source.insertAll(logs);

      expect(
        (await db.query('food_log', where: 'user_id = ?', whereArgs: <Object?>['user-1']))
            .length,
        count,
      );
      expect(await eventsFor('food_log'), hasLength(count));
      final List<FoodLog> day = await source.getByDateRange(
        'user-1',
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 3),
      );
      expect(day, hasLength(count));
      final List<Map<String, Object?>> uniqueUuids =
          await db.rawQuery('SELECT COUNT(DISTINCT uuid) AS n FROM food_log');
      expect(uniqueUuids.single['n'], count);
    });

    test('registry maps food_log food FK to the cloud food_id name', () {
      final SyncTableMapping? mapping = SyncTableRegistry.byLocalTable('food_log');
      expect(mapping, isNotNull);
      expect(mapping!.cloudTable, 'food_logs');
      expect(mapping.cloudForeignKeys['food_item_id'], 'food_item');
      expect(mapping.cloudForeignKeys['meal_id'], 'meal');
      expect(mapping.cloudForeignKeyNames['food_item_id'], 'food_id');
    });
  });

  group('food_favorite', () {
    setUp(setUpDb);

    FoodItemLocalDataSource dao() =>
        FoodItemLocalDataSource(database: appDatabase);

    test('addFavorite generates uuid and a CREATE event', () async {
      final int foodId = await insertFood('food-uuid-1');
      await dao().addFavorite('user-1', foodId);
      final List<Map<String, Object?>> rows = await db.query('food_favorite');
      expect(rows.single['uuid'], matches(_uuidRegex));
      expect(rows.single['row_version'], 1);
      expect(rows.single['food_item_id'], foodId);
      final List<Map<String, Object?>> events = await eventsFor('food_favorite');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], rows.single['uuid'] as String);
    });

    test('removeFavorite soft-deletes and records a DELETE event', () async {
      final FoodItemLocalDataSource source = dao();
      final int foodId = await insertFood('food-uuid-1');
      await source.addFavorite('user-1', foodId);
      await source.removeFavorite('user-1', foodId);
      final List<Map<String, Object?>> rows = await db.query('food_favorite');
      expect(rows.single['deleted_at'], isNotNull);
      expect(rows.single['row_version'], 2);
      expect(await source.getFavoriteIds('user-1'), isEmpty);
      final List<Map<String, Object?>> events = await eventsFor('food_favorite');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('re-adding a removed favorite resurrects it', () async {
      final FoodItemLocalDataSource source = dao();
      final int foodId = await insertFood('food-uuid-1');
      await source.addFavorite('user-1', foodId);
      await source.removeFavorite('user-1', foodId);
      await source.addFavorite('user-1', foodId);
      final List<Map<String, Object?>> rows = await db.query('food_favorite');
      expect(rows.single['deleted_at'], isNull);
      expect(rows.single['row_version'], 3);
      expect(await source.getFavoriteIds('user-1'), <int>{foodId});
    });

    test('ownership: a different user than the authenticated one is rejected',
        () async {
      final FoodItemLocalDataSource source = dao();
      await expectLater(
        () => source.addFavorite('user-2', 9),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        () => source.removeFavorite('user-2', 9),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('food_favorite'), isEmpty);
      expect(await eventsFor('food_favorite'), isEmpty);
    });

    test('remote apply uses the cloud food_id name and records no event',
        () async {
      final int foodId = await insertFood('food-uuid-1');

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'food_favorites',
            recordId: 'fav-food-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'fav-food-1',
              'user_id': 'user-1',
              'food_id': 'food-uuid-1',
              'row_version': 1,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 1, 1)),
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query('food_favorite');
      expect(rows.single['uuid'], 'fav-food-1');
      expect(rows.single['food_item_id'], foodId);
      expect(await eventsFor('food_favorite'), isEmpty);
    });
  });

  group('meal (parent)', () {
    setUp(setUpDb);

    MealLocalDataSource dao() => MealLocalDataSource(database: appDatabase);

    Meal meal({String userId = 'user-1'}) => Meal(
          userId: userId,
          name: 'Chicken Bowl',
          calories: 500,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );

    test('insert generates uuid, stamps version 1 and a CREATE event', () async {
      final int id = await dao().insert(meal());
      final Map<String, Object?> row = await rowById('meal', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['user_id'], 'user-1');
      final List<Map<String, Object?>> events = await eventsFor('meal');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
    });

    test('update preserves uuid, bumps version and records base_version',
        () async {
      final MealLocalDataSource source = dao();
      final int id = await source.insert(meal());
      final String uuid = await uuidById('meal', id);

      await source.update(meal().copyWith(id: id, calories: 600));

      final Map<String, Object?> row = await rowById('meal', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['calories'], 600);
      final List<Map<String, Object?>> events = await eventsFor('meal');
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete tombstones the meal AND its children with DELETE events',
        () async {
      final MealLocalDataSource source = dao();
      final int foodId = await insertFood('food-uuid-1');
      final int mealId = await source.insert(meal());
      final MealItemLocalDataSource items = MealItemLocalDataSource(
        database: appDatabase,
      );
      final int childId = await items.insert(
        MealItem(mealId: mealId, foodItemId: foodId),
      );

      await source.delete(mealId);

      final Map<String, Object?> mealRow = await rowById('meal', mealId);
      expect(mealRow['deleted_at'], isNotNull);
      final Map<String, Object?> childRow =
          await rowById('meal_item', childId);
      expect(childRow['deleted_at'], isNotNull);
      final List<Map<String, Object?>> mealEvents = await eventsFor('meal');
      expect(mealEvents.last['operation'], SyncOperation.delete.name);
      final List<Map<String, Object?>> childEvents = await eventsFor('meal_item');
      expect(childEvents.last['operation'], SyncOperation.delete.name);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(dao().insert(meal(userId: 'ghost-user')), throwsA(anything));
      expect(
        await db.query('meal', where: 'user_id = ?', whereArgs: <Object?>['ghost-user']),
        isEmpty,
      );
      expect(await eventsFor('meal'), isEmpty);
    });

    test('remote apply updates the local row and creates no outbound event',
        () async {
      final MealLocalDataSource source = dao();
      final int id = await source.insert(meal());
      final String uuid = await uuidById('meal', id);

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'meals',
            recordId: uuid,
            operation: SyncOperation.update,
            payload: <String, Object?>{
              'id': uuid,
              'user_id': 'user-1',
              'name': 'Beef Bowl',
              'calories': 650,
              'is_favorite': true,
              'row_version': 4,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 2, 1)),
            },
          ),
        );
      });

      final Map<String, Object?> row = await rowById('meal', id);
      expect(row['name'], 'Beef Bowl');
      expect(row['calories'], 650);
      expect(row['is_favorite'], 1);
      expect(row['row_version'], 4);
      expect(await eventsFor('meal'), hasLength(1));
    });

    test('events are scoped per user', () async {
      await dao().insert(meal(userId: 'user-1'));
      await dao().insert(meal(userId: 'user-2'));
      final List<Map<String, Object?>> events = await eventsFor('meal');
      expect(
        events.map((Map<String, Object?> e) => e['user_id']),
        containsAll(<Object?>['user-1', 'user-2']),
      );
    });
  });

  group('meal_item (child)', () {
    setUp(setUpDb);

    MealItemLocalDataSource dao() =>
        MealItemLocalDataSource(database: appDatabase);

    test('insert resolves user_id from the parent meal and records a CREATE event',
        () async {
      final int foodId = await insertFood('food-uuid-1');
      final int mealId = await insertMeal('user-1');
      final int id = await dao().insert(
        MealItem(mealId: mealId, foodItemId: foodId, quantity: 2),
      );
      final Map<String, Object?> row = await rowById('meal_item', id);
      expect(row['user_id'], 'user-1');
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      final List<Map<String, Object?>> events = await eventsFor('meal_item');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['user_id'], 'user-1');
    });

    test('update preserves uuid, bumps version and records base_version',
        () async {
      final int foodId = await insertFood('food-uuid-1');
      final int mealId = await insertMeal('user-1');
      final MealItemLocalDataSource source = dao();
      final int id = await source.insert(
        MealItem(mealId: mealId, foodItemId: foodId),
      );
      final String uuid = await uuidById('meal_item', id);

      await source.update(
        MealItem(id: id, mealId: mealId, foodItemId: foodId, quantity: 3),
      );

      final Map<String, Object?> row = await rowById('meal_item', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['quantity'], 3);
      final List<Map<String, Object?>> events = await eventsFor('meal_item');
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('delete soft-deletes and records a DELETE event', () async {
      final int foodId = await insertFood('food-uuid-1');
      final int mealId = await insertMeal('user-1');
      final MealItemLocalDataSource source = dao();
      final int id = await source.insert(
        MealItem(mealId: mealId, foodItemId: foodId),
      );
      await source.delete(id);
      final Map<String, Object?> row = await rowById('meal_item', id);
      expect(row['deleted_at'], isNotNull);
      expect(row['row_version'], 2);
      final List<Map<String, Object?>> events = await eventsFor('meal_item');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('deleteByMeal soft-deletes every child with DELETE events', () async {
      final int foodId = await insertFood('food-uuid-1');
      final int mealId = await insertMeal('user-1');
      final MealItemLocalDataSource source = dao();
      final int childA = await source.insert(
        MealItem(mealId: mealId, foodItemId: foodId, sortOrder: 0),
      );
      final int childB = await source.insert(
        MealItem(mealId: mealId, foodItemId: foodId, sortOrder: 1),
      );

      await source.deleteByMeal(mealId);

      expect((await rowById('meal_item', childA))['deleted_at'], isNotNull);
      expect((await rowById('meal_item', childB))['deleted_at'], isNotNull);
      expect(await source.getByMeal(mealId), isEmpty);
      final List<Map<String, Object?>> events = await eventsFor('meal_item');
      expect(events, hasLength(4));
      expect(events.last['operation'], SyncOperation.delete.name);
    });

    test('a failing insert (missing parent meal) rolls back row and event',
        () async {
      await expectLater(
        dao().insert(MealItem(mealId: 9999, foodItemId: 1)),
        throwsA(anything),
      );
      expect(await db.query('meal_item'), isEmpty);
      expect(await eventsFor('meal_item'), isEmpty);
    });

    test('remote apply resolves meal + food uuids and records no event',
        () async {
      final int foodId = await insertFood('food-uuid-1');
      final int mealId = await insertMeal('user-1');
      final String mealUuid = await uuidById('meal', mealId);

      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'meal_items',
            recordId: 'mi-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'mi-uuid-1',
              'user_id': 'user-1',
              'meal_id': mealUuid,
              'food_id': 'food-uuid-1',
              'quantity': 1,
              'sort_order': 0,
              'row_version': 1,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 1, 1)),
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query(
        'meal_item',
        where: 'uuid = ?',
        whereArgs: <Object?>['mi-uuid-1'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['meal_id'], mealId);
      expect(rows.single['food_item_id'], foodId);
      expect(rows.single['row_version'], 1);
      expect(await eventsFor('meal_item'), isEmpty);
    });

    test('registry maps meal_item with its foreign keys and cloud names', () {
      final SyncTableMapping? mapping =
          SyncTableRegistry.byLocalTable('meal_item');
      expect(mapping, isNotNull);
      expect(mapping!.cloudTable, 'meal_items');
      expect(mapping.cloudForeignKeys['meal_id'], 'meal');
      expect(mapping.cloudForeignKeys['food_item_id'], 'food_item');
      expect(mapping.cloudForeignKeyNames['food_item_id'], 'food_id');
    });
  });

  group('parent/child ordering', () {
    setUp(setUpDb);

    test('orderChangesForApply places parents before children', () {
      final SyncChange meal = SyncChange(
        cursorId: 2,
        cloudTable: 'meals',
        recordId: 'meal-uuid',
        operation: SyncOperation.create,
        payload: <String, Object?>{},
      );
      final SyncChange item = SyncChange(
        cursorId: 1,
        cloudTable: 'meal_items',
        recordId: 'item-uuid',
        operation: SyncOperation.create,
        payload: <String, Object?>{},
      );

      final List<SyncChange> ordered = orderChangesForApply(<SyncChange>[item, meal]);

      expect(ordered.first.cloudTable, 'meals');
      expect(ordered.last.cloudTable, 'meal_items');
    });

    test('orderChangesForApply preserves original order within one table', () {
      final SyncChange a = SyncChange(
        cursorId: 1,
        cloudTable: 'food_logs',
        recordId: 'a',
        operation: SyncOperation.create,
        payload: <String, Object?>{},
      );
      final SyncChange b = SyncChange(
        cursorId: 2,
        cloudTable: 'food_logs',
        recordId: 'b',
        operation: SyncOperation.create,
        payload: <String, Object?>{},
      );
      expect(orderChangesForApply(<SyncChange>[a, b]), <SyncChange>[a, b]);
    });

    test('a meal_item applies in the same batch as its parent meal', () async {
      final int foodId = await insertFood('food-uuid-1');

      await db.transaction((Transaction txn) async {
        for (final SyncChange change
            in orderChangesForApply(<SyncChange>[
          SyncChange(
            cursorId: 1,
            cloudTable: 'meal_items',
            recordId: 'mi-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'mi-uuid-1',
              'user_id': 'user-1',
              'meal_id': 'meal-uuid-1',
              'food_id': 'food-uuid-1',
              'quantity': 1,
              'row_version': 1,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 1, 1)),
            },
          ),
          SyncChange(
            cursorId: 2,
            cloudTable: 'meals',
            recordId: 'meal-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'meal-uuid-1',
              'user_id': 'user-1',
              'name': 'Chicken Bowl',
              'calories': 500,
              'row_version': 1,
              'created_at': _iso(DateTime.utc(2026, 1, 1)),
              'updated_at': _iso(DateTime.utc(2026, 1, 1)),
            },
          ),
        ])) {
          await applier.apply(txn, change);
        }
      });

      final List<Map<String, Object?>> meals = await db.query(
        'meal',
        where: 'uuid = ?',
        whereArgs: <Object?>['meal-uuid-1'],
      );
      final List<Map<String, Object?>> items = await db.query(
        'meal_item',
        where: 'uuid = ?',
        whereArgs: <Object?>['mi-uuid-1'],
      );
      expect(meals, hasLength(1));
      expect(items, hasLength(1));
      expect(items.single['meal_id'], meals.single['id']);
      expect(items.single['food_item_id'], foodId);
    });
  });

  group('meal_category (master data)', () {
    setUp(setUpDb);

    test('is master data and stays outbox-exempt (no user outbox mapping)',
        () {
      expect(SyncTableRegistry.byLocalTable('meal_category'), isNull);
      expect(SyncTableRegistry.byCloudTable('meal_categories'), isNull);
    });
  });
}