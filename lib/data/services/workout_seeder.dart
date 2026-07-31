import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../datasources/local/app_database.dart';
import '../datasources/local/workout_seed_data.dart';
import '../models/exercise_model.dart';
import '../models/workout_category_model.dart';
import '../models/workout_exercise_model.dart';
import '../models/workout_model.dart';

/// Provisions the offline workout library.
///
/// Built-in exercises are global (seeded once, `INSERT OR IGNORE` by name),
/// while the default workout routines are copied per user so that every
/// account gets a personalised, editable library backed entirely by SQLite.
class WorkoutSeeder {
  WorkoutSeeder({
    required this._database,
    Logger? logger,
  }) : _logger = logger ?? Logger('WorkoutSeeder');

  final AppDatabase _database;
  final Logger _logger;

  /// Seeds the global exercise catalog if it is empty and then provisions the
  /// default workout routines for [userId]. Safe to call repeatedly.
  Future<void> seedForUser(String userId) async {
    await _database.inTransaction((Transaction txn) async {
      await _seedExercises(txn);
      await _seedWorkouts(txn, userId);
    });
  }

  Future<void> _seedExercises(Transaction txn) async {
    final List<Map<String, Object?>> existing = await txn.query(
      ExerciseModel.table,
      columns: <String>['name'],
      where: 'user_id IS NULL',
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    _logger.info('Seeding ${kSeedExercises.length} built-in exercises');
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Batch batch = txn.batch();
    for (final SeedExercise exercise in kSeedExercises) {
      batch.rawInsert(
        'INSERT OR IGNORE INTO ${ExerciseModel.table} '
        '(name, description, instructions, body_part, equipment, difficulty, '
        'image, calories_per_minute, is_custom, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, NULL, ?, 0, ?)',
        <Object?>[
          exercise.name,
          exercise.description,
          exercise.instructionsText,
          exercise.bodyPart,
          exercise.equipment,
          exercise.difficulty.name,
          exercise.caloriesPerMinute,
          now,
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedWorkouts(Transaction txn, String userId) async {
    final List<Map<String, Object?>> existing = await txn.rawQuery(
      'SELECT COUNT(*) AS count FROM ${WorkoutModel.table} '
      'WHERE user_id = ? AND is_custom = 0',
      <Object?>[userId],
    );
    if ((existing.first['count'] as int? ?? 0) > 0) return;

    final Map<String, int> categoryIds = <String, int>{};
    for (final Map<String, Object?> row in await txn.query(
      WorkoutCategoryModel.table,
      columns: <String>['id', 'slug'],
    )) {
      categoryIds[row['slug'] as String] = row['id'] as int;
    }

    final Map<String, int> exerciseIds = <String, int>{};
    for (final Map<String, Object?> row in await txn.query(
      ExerciseModel.table,
      columns: <String>['id', 'name'],
      where: 'user_id IS NULL',
    )) {
      exerciseIds[row['name'] as String] = row['id'] as int;
    }

    _logger.info(
      'Seeding ${kSeedWorkouts.length} workouts for user $userId',
    );

    final int now = DateTime.now().millisecondsSinceEpoch;
    final Batch batch = txn.batch();

    for (final SeedWorkout workout in kSeedWorkouts) {
      final int? categoryId = categoryIds[workout.categorySlug];
      batch.insert(
        WorkoutModel.table,
        <String, Object?>{
          'user_id': userId,
          'category_id': categoryId,
          'name': workout.name,
          'description': workout.description,
          'difficulty': workout.difficulty.name,
          'duration_minutes': workout.durationMinutes,
          'calories_burn': workout.calories,
          'image': null,
          'is_favorite': 0,
          'is_custom': 0,
          'created_at': now,
          'updated_at': now,
        },
      );
    }

    await batch.commit(noResult: true);

    final List<Map<String, Object?>> inserted = await txn.rawQuery(
      'SELECT id, name FROM ${WorkoutModel.table} '
      'WHERE user_id = ? AND is_custom = 0 ORDER BY id ASC',
      <Object?>[userId],
    );
    final Map<String, int> workoutIds = <String, int>{
      for (int i = 0; i < inserted.length; i++)
        inserted[i]['name'] as String: inserted[i]['id'] as int,
    };

    final Batch linkBatch = txn.batch();
    for (final SeedWorkout workout in kSeedWorkouts) {
      final int? workoutId = workoutIds[workout.name];
      if (workoutId == null) continue;
      int sortOrder = 0;
      for (final SeedWorkoutExercise item in workout.exercises) {
        final int? exerciseId = exerciseIds[item.exerciseName];
        if (exerciseId == null) continue;
        linkBatch.insert(
          WorkoutExerciseModel.table,
          <String, Object?>{
            'workout_id': workoutId,
            'exercise_id': exerciseId,
            'sets': item.sets,
            'reps': item.reps,
            'duration_seconds': item.durationSeconds,
            'rest_seconds': item.restSeconds,
            'sort_order': sortOrder++,
          },
        );
      }
    }
    await linkBatch.commit(noResult: true);
  }
}
