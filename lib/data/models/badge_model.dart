import '../../domain/entities/badge.dart';
import 'model_codec.dart';

/// Maps [Badge] to and from rows in the `badge` table.
class BadgeModel {
  BadgeModel._();

  static const String table = 'badge';

  static Map<String, Object?> toMap(Badge badge) {
    return <String, Object?>{
      'id': badge.id,
      'user_id': badge.userId,
      'badge_type': badge.badgeType,
      'badge_name': badge.badgeName,
      'icon': badge.icon,
      'level': badge.level,
      'progress': badge.progress,
      'target': badge.target,
      'is_earned': ModelCodec.boolToInt(badge.isEarned),
      'earned_at': ModelCodec.epochMs(badge.earnedAt),
      'created_at': ModelCodec.epochMs(badge.createdAt),
      'updated_at': ModelCodec.epochMs(badge.updatedAt),
    };
  }

  static Badge fromMap(Map<String, Object?> row) {
    return Badge(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      badgeType: row['badge_type'] as String,
      badgeName: row['badge_name'] as String,
      icon: row['icon'] as String?,
      level: ModelCodec.toInt(row['level']),
      progress: ModelCodec.toDouble(row['progress']) ?? 0,
      target: ModelCodec.toDouble(row['target']) ?? 0,
      isEarned: ModelCodec.intToBool(row['is_earned']),
      earnedAt: ModelCodec.fromEpochMs(row['earned_at'] as int?),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
