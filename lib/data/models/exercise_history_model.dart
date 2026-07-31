import '../../domain/entities/exercise_history.dart';
import 'model_codec.dart';

/// Maps [ExerciseHistory] to and from rows in the `exercise_history` table.
class ExerciseHistoryModel {
  ExerciseHistoryModel._();

  static const String table = 'exercise_history';

  static Map<String, Object?> toMap(ExerciseHistory history) {
    return <String, Object?>{
      'id': history.id,
      'workout_history_id': history.workoutHistoryId,
      'exercise_id': history.exerciseId,
      'sets': history.sets,
      'reps': history.reps,
      'weight_kg': history.weightKg,
      'duration_seconds': history.durationSeconds,
      'completed_at': ModelCodec.epochMs(history.completedAt),
    };
  }

  static ExerciseHistory fromMap(Map<String, Object?> row) {
    return ExerciseHistory(
      id: row['id'] as int?,
      workoutHistoryId: ModelCodec.toInt(row['workout_history_id']),
      exerciseId: row['exercise_id'] as int?,
      sets: ModelCodec.toInt(row['sets']),
      reps: ModelCodec.toInt(row['reps']),
      weightKg: ModelCodec.toDouble(row['weight_kg']),
      durationSeconds: row['duration_seconds'] as int?,
      completedAt: ModelCodec.fromEpochMs(row['completed_at'] as int?),
    );
  }
}
