import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/constants/app_constants.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const List<String> syncableTables = <String>[
  'user_profile', 'fitness_goal', 'workout', 'exercise', 'workout_exercise',
  'workout_history', 'exercise_history', 'meal', 'food_item', 'food_log',
  'water_log', 'weight_log', 'bmi_log', 'body_measurement', 'sleep_log',
  'step_log', 'reminder', 'achievement', 'badge', 'streak', 'daily_progress',
  'app_settings', 'exercise_favorite', 'food_favorite', 'meal_item',
  'reminder_history', 'xp_history', 'user_level', 'challenge', 'milestone',
  'reward',
];

final String seedDbPath =
    path.join(Directory.current.path, 'test', 'fixtures', 'nexfit_v14_seed.db');
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<String> databasePath() async =>
      path.join(await databaseFactory.getDatabasesPath(), AppConstants.databaseName);

  group('fresh install (v1-v15)', () {
    late AppDatabase appDatabase;

    setUp(() async {
      await databaseFactory.deleteDatabase(await databasePath());
      appDatabase = AppDatabase();
      await appDatabase.database;
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('all 31 syncable tables have uuid/updated_at/deleted_at/row_version',
        () async {
      final db = await appDatabase.database;
      for (final String table in syncableTables) {
        final List<Map<String, Object?>> columns =
            await db.rawQuery('PRAGMA table_info($table)');
        final Set<String> names = columns
            .map((Map<String, Object?> row) => row['name'] as String)
            .toSet();
        expect(names, contains('uuid'), reason: '$table.uuid');
        expect(names, contains('updated_at'), reason: '$table.updated_at');
        expect(names, contains('deleted_at'), reason: '$table.deleted_at');
        expect(names, contains('row_version'), reason: '$table.row_version');
      }
    });

    test('child tables gained user_id; singletons keep uuid = user_id', () async {
      final db = await appDatabase.database;
      for (final String table in <String>[
        'workout_exercise', 'exercise_history', 'meal_item',
      ]) {
        final List<Map<String, Object?>> columns =
            await db.rawQuery('PRAGMA table_info($table)');
        final Set<String> names = columns
            .map((Map<String, Object?> row) => row['name'] as String)
            .toSet();
        expect(names, contains('user_id'), reason: '$table.user_id');
      }

      final List<Map<String, Object?>> profileColumns =
          await db.rawQuery('PRAGMA table_info(user_profile)');
      final Set<String> profileNames = profileColumns
          .map((Map<String, Object?> row) => row['name'] as String)
          .toSet();
      expect(profileNames, contains('created_at'));
    });

    test('sync_state exists empty; sync_event gained 4 columns', () async {
      final db = await appDatabase.database;

      final int syncStateCount =
          Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_state'))!;
      expect(syncStateCount, 0);

      final List<Map<String, Object?>> syncEventColumns =
          await db.rawQuery('PRAGMA table_info(sync_event)');
      final Set<String> names = syncEventColumns
          .map((Map<String, Object?> row) => row['name'] as String)
          .toSet();
      expect(names, containsAll(<String>[
        'event_uuid', 'device_id', 'base_version', 'next_retry_at',
      ]));
    });

    test('seeded fitness_goal rows get unique backfilled uuids', () async {
      final db = await appDatabase.database;
      final List<Map<String, Object?>> rows =
          await db.rawQuery('SELECT uuid FROM fitness_goal');
      expect(rows, isNotEmpty, reason: 'v2 seed should insert 4 goal templates');
      final Set<String> uuids = rows
          .map((Map<String, Object?> row) => row['uuid'] as String)
          .toSet();
      expect(uuids.length, rows.length,
          reason: 'every seeded row needs a unique uuid');
      expect(uuids.every((String u) => u.contains('-')), isTrue);
    });

    test('new indexes exist', () async {
      final db = await appDatabase.database;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name IN "
        "('idx_weight_log_uuid','idx_weight_log_user_updated',"
        "'idx_workout_exercise_uuid','idx_user_profile_uuid',"
        "'idx_sync_event_event_uuid','idx_sync_event_device')",
      );
      final Set<String> names = rows
          .map((Map<String, Object?> row) => row['name'] as String)
          .toSet();
      expect(names, containsAll(<String>[
        'idx_weight_log_uuid',
        'idx_weight_log_user_updated',
        'idx_workout_exercise_uuid',
        'idx_user_profile_uuid',
        'idx_sync_event_event_uuid',
        'idx_sync_event_device',
      ]));
    });

    test('version 15 recorded in schema_migrations', () async {
      final db = await appDatabase.database;
      final int version = Sqflite.firstIntValue(await db
          .rawQuery("SELECT version FROM schema_migrations WHERE version = 15"))!;
      expect(version, 15);
    });
  });

  group('v14 -> v15 upgrade', () {
    late AppDatabase appDatabase;

    setUp(() async {
      final File seed = File(seedDbPath);
      expect(seed.existsSync(), isTrue, reason: 'v14 seed DB must exist');
      final String target = await databasePath();
      await databaseFactory.deleteDatabase(target);
      await seed.copy(target);
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('version recorded and sync columns added', () async {
      appDatabase = AppDatabase();
      final db = await appDatabase.database;

      final int version = Sqflite.firstIntValue(await db
          .rawQuery("SELECT version FROM schema_migrations WHERE version = 15"))!;
      expect(version, 15);

      final List<Map<String, Object?>> weightColumns =
          await db.rawQuery('PRAGMA table_info(weight_log)');
      final Set<String> weightNames = weightColumns
          .map((Map<String, Object?> row) => row['name'] as String)
          .toSet();
      expect(weightNames, containsAll(<String>[
        'uuid', 'updated_at', 'deleted_at', 'row_version',
      ]));
    });

    test('existing rows backfilled with unique uuids', () async {
      appDatabase = AppDatabase();
      final db = await appDatabase.database;

      final List<Map<String, Object?>> weights =
          await db.rawQuery('SELECT uuid, deleted_at, row_version FROM weight_log');
      expect(weights, hasLength(1));
      final String? uuid = weights.single['uuid'] as String?;
      expect(uuid, isNotNull);
      expect(uuid, isNotEmpty);
      expect(uuid, contains('-'));
      expect(weights.single['deleted_at'], isNull);
      expect(weights.single['row_version'], 0);
    });

    test('updated_at backfilled from created_at', () async {
      appDatabase = AppDatabase();
      final db = await appDatabase.database;

      final List<Map<String, Object?>> rows =
          await db.rawQuery('SELECT created_at, updated_at FROM weight_log');
      expect(rows.single['updated_at'], rows.single['created_at']);
    });

    test('singletons uuid = user_id', () async {
      appDatabase = AppDatabase();
      final db = await appDatabase.database;

      final List<Map<String, Object?>> profile =
          await db.rawQuery('SELECT user_id, uuid FROM user_profile');
      expect(profile.single['uuid'], 'upgrade-user');

      final List<Map<String, Object?>> settings =
          await db.rawQuery('SELECT user_id, uuid FROM app_settings');
      expect(settings.single['uuid'], 'upgrade-user');
    });

    test('child tables get user_id and uuid from backfill', () async {
      appDatabase = AppDatabase();
      final db = await appDatabase.database;

      final List<Map<String, Object?>> workoutExercises =
          await db.rawQuery('SELECT user_id, uuid, created_at FROM workout_exercise');
      expect(workoutExercises, hasLength(1));
      expect(workoutExercises.single['user_id'], 'upgrade-user');
      expect(workoutExercises.single['uuid'], isNotNull);
      expect(workoutExercises.single['created_at'], isNotNull);

      final List<Map<String, Object?>> exerciseHistories = await db
          .rawQuery('SELECT user_id, uuid FROM exercise_history');
      expect(exerciseHistories.single['user_id'], 'upgrade-user');
      expect(exerciseHistories.single['uuid'], isNotNull);

      final List<Map<String, Object?>> mealItems =
          await db.rawQuery('SELECT user_id, uuid FROM meal_item');
      expect(mealItems.single['user_id'], 'upgrade-user');
      expect(mealItems.single['uuid'], isNotNull);
    });

    test('exercise/food_item custom rows get uuids', () async {
      appDatabase = AppDatabase();
      final db = await appDatabase.database;

      final List<Map<String, Object?>> exercises =
          await db.rawQuery('SELECT user_id, uuid FROM exercise WHERE is_custom = 1');
      expect(exercises, hasLength(1));
      expect(exercises.single['uuid'], isNotNull);

      final List<Map<String, Object?>> foods =
          await db.rawQuery('SELECT user_id, uuid FROM food_item WHERE is_custom = 1');
      expect(foods, hasLength(1));
      expect(foods.single['uuid'], isNotNull);
    });

    test('composite-PK favorites get uuids', () async {
      appDatabase = AppDatabase();
      final db = await appDatabase.database;

      final List<Map<String, Object?>> exerciseFavorites = await db
          .rawQuery('SELECT uuid FROM exercise_favorite');
      expect(exerciseFavorites.single['uuid'], isNotNull);

      final List<Map<String, Object?>> foodFavorites =
          await db.rawQuery('SELECT uuid FROM food_favorite');
      expect(foodFavorites.single['uuid'], isNotNull);
    });

    test('data preserved and sync_event extended', () async {
      appDatabase = AppDatabase();
      final db = await appDatabase.database;

      expect(
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM weight_log'))!,
        1,
      );
      expect(
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM workout'))!,
        1,
      );
      expect(
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM meal'))!,
        1,
      );
      expect(
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users'))!,
        1,
      );

      final List<Map<String, Object?>> syncEventColumns =
          await db.rawQuery('PRAGMA table_info(sync_event)');
      final Set<String> names = syncEventColumns
          .map((Map<String, Object?> row) => row['name'] as String)
          .toSet();
      expect(names, containsAll(<String>[
        'event_uuid', 'device_id', 'base_version', 'next_retry_at',
      ]));

      final List<Map<String, Object?>> events = await db.rawQuery(
          'SELECT entity, entity_id FROM sync_event WHERE operation = ? AND status = ?',
          <Object?>['create', 'pending']);
      expect(events, hasLength(1));
      expect(events.single['entity_id'], '1');
    });

    test('new indexes exist', () async {
      appDatabase = AppDatabase();
      final db = await appDatabase.database;

      final List<Map<String, Object?>> rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name IN "
        "('idx_weight_log_uuid','idx_weight_log_user_updated',"
        "'idx_sync_event_event_uuid','idx_sync_event_device')",
      );
      final Set<String> names = rows
          .map((Map<String, Object?> row) => row['name'] as String)
          .toSet();
      expect(names, containsAll(<String>[
        'idx_weight_log_uuid',
        'idx_weight_log_user_updated',
        'idx_sync_event_event_uuid',
        'idx_sync_event_device',
      ]));
    });

    test('row_version default 0 everywhere', () async {
      appDatabase = AppDatabase();
      final db = await appDatabase.database;

      for (final String table in <String>[
        'weight_log', 'workout', 'workout_exercise', 'meal_item', 'exercise',
        'food_item', 'exercise_favorite', 'food_favorite', 'user_profile',
        'app_settings', 'exercise_history', 'meal',
      ]) {
        final int nullCount = Sqflite.firstIntValue(await db.rawQuery(
                'SELECT COUNT(*) FROM $table WHERE row_version IS NULL OR row_version != 0'))!;
        expect(nullCount, 0, reason: '$table row_version defaults to 0');
      }
    });
  });
}