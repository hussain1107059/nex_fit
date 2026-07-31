import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/workout_exercise.dart';
import '../../../domain/entities/workout_exercise_detail.dart';
import '../../models/exercise_model.dart';
import '../../models/workout_exercise_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `workout_exercise` join table.
class WorkoutExerciseLocalDataSource extends BaseLocalDataSource {
  WorkoutExerciseLocalDataSource({required super.database})
    : super(logName: 'WorkoutExerciseLocalDataSource');

  Future<int> insert(WorkoutExercise workoutExercise) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        WorkoutExerciseModel.table,
        WorkoutExerciseModel.toMap(workoutExercise),
      );
    });
  }

  Future<void> update(WorkoutExercise workoutExercise) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        WorkoutExerciseModel.table,
        WorkoutExerciseModel.toMap(workoutExercise),
        where: 'id = ?',
        whereArgs: <Object?>[workoutExercise.id],
      );
    });
  }

  Future<WorkoutExercise?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutExerciseModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WorkoutExerciseModel.fromMap(rows.first);
    });
  }

  Future<List<WorkoutExercise>> getByWorkout(int workoutId) {
    return guard('get_by_workout', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutExerciseModel.table,
        where: 'workout_id = ?',
        whereArgs: <Object?>[workoutId],
        orderBy: 'sort_order ASC, id ASC',
      );
      return rows.map(WorkoutExerciseModel.fromMap).toList();
    });
  }

  /// All join rows for [workoutId] joined with their exercise payload.
  Future<List<WorkoutExerciseDetail>> getDetailsByWorkout(int workoutId) {
    return guard('get_details_by_workout', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        '$_joinSelect WHERE we.workout_id = ? '
        'ORDER BY we.sort_order ASC, we.id ASC',
        <Object?>[workoutId],
      );
      return rows.map(_fromJoinedRow).toList();
    });
  }

  /// Join rows for several workouts in a single query, grouped by workout.
  Future<Map<int, List<WorkoutExerciseDetail>>> getDetailsByWorkouts(
    List<int> workoutIds,
  ) {
    return guard('get_details_by_workouts', () async {
      if (workoutIds.isEmpty) return const <int, List<WorkoutExerciseDetail>>{};
      final Database db = await dbConnection;
      final String placeholders = List<String>.filled(
        workoutIds.length,
        '?',
      ).join(', ');
      final List<Map<String, Object?>> rows = await db.rawQuery(
        '$_joinSelect WHERE we.workout_id IN ($placeholders) '
        'ORDER BY we.workout_id ASC, we.sort_order ASC, we.id ASC',
        workoutIds,
      );

      final Map<int, List<WorkoutExerciseDetail>> result =
          <int, List<WorkoutExerciseDetail>>{};
      for (final Map<String, Object?> row in rows) {
        final WorkoutExerciseDetail detail = _fromJoinedRow(row);
        result
            .putIfAbsent(
              detail.workoutExercise.workoutId,
              () => <WorkoutExerciseDetail>[],
            )
            .add(detail);
      }
      return result;
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        WorkoutExerciseModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  Future<void> deleteByWorkout(int workoutId) {
    return guard('delete_by_workout', () async {
      final Database db = await dbConnection;
      await db.delete(
        WorkoutExerciseModel.table,
        where: 'workout_id = ?',
        whereArgs: <Object?>[workoutId],
      );
    });
  }

  static const String _joinSelect = '''
    SELECT
      we.id, we.workout_id, we.exercise_id, we.sets, we.reps,
      we.duration_seconds, we.rest_seconds, we.sort_order,
      e.id AS ex_id, e.user_id AS ex_user_id, e.name AS ex_name,
      e.description AS ex_description, e.instructions AS ex_instructions,
      e.body_part AS ex_body_part, e.equipment AS ex_equipment,
      e.difficulty AS ex_difficulty, e.image AS ex_image,
      e.calories_per_minute AS ex_calories_per_minute,
      e.is_custom AS ex_is_custom, e.created_at AS ex_created_at
    FROM ${WorkoutExerciseModel.table} we
    JOIN ${ExerciseModel.table} e ON e.id = we.exercise_id
  ''';

  WorkoutExerciseDetail _fromJoinedRow(Map<String, Object?> row) {
    final WorkoutExercise join = WorkoutExerciseModel.fromMap(row);
    final Exercise exercise = ExerciseModel.fromMap(_exerciseColumns(row));
    return WorkoutExerciseDetail(workoutExercise: join, exercise: exercise);
  }

  Map<String, Object?> _exerciseColumns(Map<String, Object?> row) {
    return <String, Object?>{
      'id': row['ex_id'],
      'user_id': row['ex_user_id'],
      'name': row['ex_name'],
      'description': row['ex_description'],
      'instructions': row['ex_instructions'],
      'body_part': row['ex_body_part'],
      'equipment': row['ex_equipment'],
      'difficulty': row['ex_difficulty'],
      'image': row['ex_image'],
      'calories_per_minute': row['ex_calories_per_minute'],
      'is_custom': row['ex_is_custom'],
      'created_at': row['ex_created_at'],
    };
  }
}
