import '../../domain/entities/workout_exercise.dart';
import 'model_codec.dart';

/// Maps [WorkoutExercise] to and from rows in the `workout_exercise` table.
class WorkoutExerciseModel {
  WorkoutExerciseModel._();

  static const String table = 'workout_exercise';

  static Map<String, Object?> toMap(WorkoutExercise workoutExercise) {
    return <String, Object?>{
      'id': workoutExercise.id,
      'workout_id': workoutExercise.workoutId,
      'exercise_id': workoutExercise.exerciseId,
      'sets': workoutExercise.sets,
      'reps': workoutExercise.reps,
      'duration_seconds': workoutExercise.durationSeconds,
      'rest_seconds': workoutExercise.restSeconds,
      'sort_order': workoutExercise.sortOrder,
    };
  }

  static WorkoutExercise fromMap(Map<String, Object?> row) {
    return WorkoutExercise(
      id: row['id'] as int?,
      workoutId: ModelCodec.toInt(row['workout_id']),
      exerciseId: ModelCodec.toInt(row['exercise_id']),
      sets: ModelCodec.toInt(row['sets']),
      reps: ModelCodec.toInt(row['reps']),
      durationSeconds: ModelCodec.toInt(row['duration_seconds']),
      restSeconds: ModelCodec.toInt(row['rest_seconds']),
      sortOrder: ModelCodec.toInt(row['sort_order']),
    );
  }
}
