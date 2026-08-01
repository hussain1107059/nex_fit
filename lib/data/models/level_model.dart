import '../../domain/entities/level.dart';
import 'model_codec.dart';

class LevelModel {
  LevelModel._();

  static const String table = 'user_level';

  static Map<String, Object?> toMap(LevelProgress levelProgress) {
    return <String, Object?>{
      'id': levelProgress.id,
      'user_id': levelProgress.userId,
      'level': levelProgress.level,
      'current_xp': levelProgress.currentXp,
      'required_xp': levelProgress.requiredXp,
      'total_xp': levelProgress.totalXp,
      'created_at': ModelCodec.epochMs(levelProgress.createdAt),
      'updated_at': ModelCodec.epochMs(levelProgress.updatedAt),
    };
  }

  static LevelProgress fromMap(Map<String, Object?> row) {
    return LevelProgress(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      level: ModelCodec.toInt(row['level']),
      currentXp: ModelCodec.toInt(row['current_xp']),
      requiredXp: ModelCodec.toInt(row['required_xp']),
      totalXp: ModelCodec.toInt(row['total_xp']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
