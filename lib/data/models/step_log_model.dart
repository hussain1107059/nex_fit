import '../../domain/entities/step_log.dart';
import 'model_codec.dart';

/// Maps [StepLog] to and from rows in the `step_log` table.
class StepLogModel {
  StepLogModel._();

  static const String table = 'step_log';

  static Map<String, Object?> toMap(StepLog log) {
    return <String, Object?>{
      'id': log.id,
      'user_id': log.userId,
      'step_date': ModelCodec.epochMs(log.stepDate),
      'steps': log.steps,
      'distance_km': log.distanceKm,
      'calories_burned': log.caloriesBurned,
      'created_at': ModelCodec.epochMs(log.createdAt),
    };
  }

  static StepLog fromMap(Map<String, Object?> row) {
    return StepLog(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      stepDate:
          ModelCodec.fromEpochMs(row['step_date'] as int?) ?? DateTime.now(),
      steps: ModelCodec.toInt(row['steps']),
      distanceKm: ModelCodec.toDouble(row['distance_km']) ?? 0,
      caloriesBurned: ModelCodec.toDouble(row['calories_burned']) ?? 0,
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
