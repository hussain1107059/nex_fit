import '../../domain/entities/calorie_log.dart';
import 'model_codec.dart';

/// Maps [CalorieLog] to and from rows in the `calorie_log` table.
class CalorieLogModel {
  CalorieLogModel._();

  static const String table = 'calorie_log';

  static Map<String, Object?> toMap(CalorieLog log) {
    return <String, Object?>{
      'id': log.id,
      'user_id': log.userId,
      'calories_consumed': log.caloriesConsumed,
      'calories_burned': log.caloriesBurned,
      'net_calories': log.netCalories,
      'logged_at': ModelCodec.epochMs(log.loggedAt),
      'created_at': ModelCodec.epochMs(log.createdAt),
    };
  }

  static CalorieLog fromMap(Map<String, Object?> row) {
    return CalorieLog(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      caloriesConsumed: ModelCodec.toDouble(row['calories_consumed']) ?? 0,
      caloriesBurned: ModelCodec.toDouble(row['calories_burned']) ?? 0,
      netCalories: ModelCodec.toDouble(row['net_calories']) ?? 0,
      loggedAt:
          ModelCodec.fromEpochMs(row['logged_at'] as int?) ?? DateTime.now(),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
