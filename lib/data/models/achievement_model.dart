import '../../domain/entities/achievement.dart';
import 'model_codec.dart';

/// Maps [Achievement] to and from rows in the `achievement` table.
class AchievementModel {
  AchievementModel._();

  static const String table = 'achievement';

  static Map<String, Object?> toMap(Achievement achievement) {
    return <String, Object?>{
      'id': achievement.id,
      'user_id': achievement.userId,
      'name': achievement.name,
      'description': achievement.description,
      'achievement_type': achievement.achievementType,
      'icon': achievement.icon,
      'is_unlocked': ModelCodec.boolToInt(achievement.isUnlocked),
      'unlocked_at': ModelCodec.epochMs(achievement.unlockedAt),
      'created_at': ModelCodec.epochMs(achievement.createdAt),
    };
  }

  static Achievement fromMap(Map<String, Object?> row) {
    return Achievement(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      achievementType: row['achievement_type'] as String?,
      icon: row['icon'] as String?,
      isUnlocked: ModelCodec.intToBool(row['is_unlocked']),
      unlockedAt: ModelCodec.fromEpochMs(row['unlocked_at'] as int?),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
