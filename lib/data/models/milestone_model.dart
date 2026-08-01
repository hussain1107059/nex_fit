import '../../domain/entities/milestone.dart';
import 'model_codec.dart';

class MilestoneModel {
  MilestoneModel._();

  static const String table = 'milestone';

  static Map<String, Object?> toMap(Milestone milestone) {
    return <String, Object?>{
      'id': milestone.id,
      'user_id': milestone.userId,
      'challenge_id': milestone.challengeId,
      'title': milestone.title,
      'target_value': milestone.targetValue,
      'current_value': milestone.currentValue,
      'is_reached': ModelCodec.boolToInt(milestone.isReached),
      'created_at': ModelCodec.epochMs(milestone.createdAt),
      'updated_at': ModelCodec.epochMs(milestone.updatedAt),
    };
  }

  static Milestone fromMap(Map<String, Object?> row) {
    return Milestone(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      challengeId: row['challenge_id'] as int?,
      title: row['title'] as String,
      targetValue: ModelCodec.toInt(row['target_value']),
      currentValue: ModelCodec.toInt(row['current_value']),
      isReached: ModelCodec.intToBool(row['is_reached']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
