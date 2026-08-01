import '../../domain/entities/workout_history.dart';
import '../services/security/encryption_service.dart';
import 'model_codec.dart';

/// Maps [WorkoutHistory] to and from rows in the `workout_history` table.
class WorkoutHistoryModel {
  WorkoutHistoryModel._();

  static const String table = 'workout_history';

  static Map<String, Object?> toMap(WorkoutHistory history) {
    return <String, Object?>{
      'id': history.id,
      'user_id': history.userId,
      'workout_id': history.workoutId,
      'started_at': ModelCodec.epochMs(history.startedAt),
      'ended_at': ModelCodec.epochMs(history.endedAt),
      'duration_minutes': history.durationMinutes,
      'calories_burn': history.caloriesBurn,
      'notes': FieldEncryption.encrypt(history.notes),
      'is_completed': ModelCodec.boolToInt(history.isCompleted),
      'created_at': ModelCodec.epochMs(history.createdAt),
    };
  }

  static WorkoutHistory fromMap(Map<String, Object?> row) {
    return WorkoutHistory(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      workoutId: row['workout_id'] as int?,
      startedAt:
          ModelCodec.fromEpochMs(row['started_at'] as int?) ?? DateTime.now(),
      endedAt: ModelCodec.fromEpochMs(row['ended_at'] as int?),
      durationMinutes: row['duration_minutes'] as int?,
      caloriesBurn: ModelCodec.toDouble(row['calories_burn']),
      notes: FieldEncryption.decrypt(row['notes'] as String?),
      isCompleted: ModelCodec.intToBool(row['is_completed']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
