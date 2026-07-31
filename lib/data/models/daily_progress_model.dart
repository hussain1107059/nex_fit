import '../../domain/entities/daily_progress.dart';
import 'model_codec.dart';

/// Maps [DailyProgress] to and from rows in the `daily_progress` table.
class DailyProgressModel {
  DailyProgressModel._();

  static const String table = 'daily_progress';

  static Map<String, Object?> toMap(DailyProgress progress) {
    return <String, Object?>{
      'id': progress.id,
      'user_id': progress.userId,
      'progress_date': ModelCodec.epochMs(progress.progressDate),
      'steps': progress.steps,
      'water_ml': progress.waterMl,
      'calories_consumed': progress.caloriesConsumed,
      'calories_burned': progress.caloriesBurned,
      'workout_minutes': progress.workoutMinutes,
      'sleep_minutes': progress.sleepMinutes,
      'weight_kg': progress.weightKg,
      'is_goal_met': ModelCodec.boolToInt(progress.isGoalMet),
      'created_at': ModelCodec.epochMs(progress.createdAt),
      'updated_at': ModelCodec.epochMs(progress.updatedAt),
    };
  }

  static DailyProgress fromMap(Map<String, Object?> row) {
    return DailyProgress(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      progressDate:
          ModelCodec.fromEpochMs(row['progress_date'] as int?) ??
              DateTime.now(),
      steps: ModelCodec.toInt(row['steps']),
      waterMl: ModelCodec.toInt(row['water_ml']),
      caloriesConsumed: ModelCodec.toDouble(row['calories_consumed']) ?? 0,
      caloriesBurned: ModelCodec.toDouble(row['calories_burned']) ?? 0,
      workoutMinutes: ModelCodec.toInt(row['workout_minutes']),
      sleepMinutes: ModelCodec.toInt(row['sleep_minutes']),
      weightKg: ModelCodec.toDouble(row['weight_kg']),
      isGoalMet: ModelCodec.intToBool(row['is_goal_met']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
