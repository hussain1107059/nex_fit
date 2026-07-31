import '../../domain/entities/common_enums.dart';
import '../../domain/entities/streak.dart';
import 'model_codec.dart';

/// Maps [Streak] to and from rows in the `streak` table.
class StreakModel {
  StreakModel._();

  static const String table = 'streak';

  static Map<String, Object?> toMap(Streak streak) {
    return <String, Object?>{
      'id': streak.id,
      'user_id': streak.userId,
      'streak_type': streak.streakType.name,
      'current_streak': streak.currentStreak,
      'longest_streak': streak.longestStreak,
      'last_active_date': ModelCodec.epochMs(streak.lastActiveDate),
      'best_date': ModelCodec.epochMs(streak.bestDate),
      'created_at': ModelCodec.epochMs(streak.createdAt),
      'updated_at': ModelCodec.epochMs(streak.updatedAt),
    };
  }

  static Streak fromMap(Map<String, Object?> row) {
    return Streak(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      streakType: StreakType.fromName(row['streak_type'] as String?),
      currentStreak: ModelCodec.toInt(row['current_streak']),
      longestStreak: ModelCodec.toInt(row['longest_streak']),
      lastActiveDate: ModelCodec.fromEpochMs(row['last_active_date'] as int?),
      bestDate: ModelCodec.fromEpochMs(row['best_date'] as int?),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
