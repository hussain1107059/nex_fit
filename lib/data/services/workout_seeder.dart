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
    // Early-return once the built-in catalog is present: this runs on every
    // workout-library build/search, and re-committing an ~84-row batch update
    // per keystroke is pure waste. A future seed version that adds new entries
    // makes the count fall short again, so it still self-heals.
    final List<Map<String, Object?>> countRows = await txn.rawQuery(
      'SELECT COUNT(*) AS count FROM ${ExerciseModel.table} '
      'WHERE user_id IS NULL',
    );
    if ((countRows.first['count'] as int? ?? 0) >= kSeedExercises.length) {
      return;
    }

    _logger.info('Seeding ${kSeedExercises.length} built-in exercises');

    final List<Map<String, Object?>> rows = await txn.query(
      ExerciseModel.table,
      columns: <String>['name'],
      where: 'user_id IS NULL',
    );
    final Set<String> existingNames = rows
        .map((Map<String, Object?> row) => row['name'] as String)
        .toSet();

    final int now = DateTime.now().millisecondsSinceEpoch;
    int updated = 0;
    int inserted = 0;

    final Batch batch = txn.batch();
    for (final SeedExercise exercise in kSeedExercises) {
      final Map<String, Object?> values = <String, Object?>{
        'name': exercise.name,
        'scientific_name': exercise.scientificName,
        'description': exercise.description,
        'instructions': exercise.instructionsText,
        'body_part': exercise.bodyPart,
        'secondary_muscle': exercise.secondaryMuscle,
        'equipment': exercise.equipment,
        'difficulty': exercise.difficulty.name,
        'category': exercise.category.name,
        'image': null,
        'gif_path': exercise.gifPath,
        'calories_per_minute': exercise.caloriesPerMinute,
        'estimated_calories': exercise.estimatedCalories,
        'duration_seconds': exercise.durationSeconds,
        'sets': exercise.sets,
        'reps': exercise.reps,
        'rest_seconds': exercise.restSeconds,
        'tips': ExerciseModel.encodeList(exercise.tips),
        'common_mistakes': ExerciseModel.encodeList(exercise.commonMistakes),
        'safety_instructions': ExerciseModel.encodeList(
          exercise.safetyInstructions,
        ),
        'is_custom': 0,
        'created_at': now,
      };

      // Backfill existing built-in rows in place (keeps ids and therefore the
      // workout_exercise links valid) and insert any new catalog entries.
      if (existingNames.contains(exercise.name)) {
        batch.update(
          ExerciseModel.table,
          values,
          where: 'user_id IS NULL AND name = ?',
          whereArgs: <Object?>[exercise.name],
        );
        updated++;
        continue;
      }
      batch.insert(ExerciseModel.table, values);
      inserted++;
    }
    await batch.commit(noResult: true);
    _logger.info('Built-in exercises seeded (updated: $updated, inserted: $inserted)');
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
