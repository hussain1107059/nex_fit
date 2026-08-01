import '../../domain/entities/challenge.dart';
import 'model_codec.dart';

class ChallengeModel {
  ChallengeModel._();

  static const String table = 'challenge';

  static Map<String, Object?> toMap(Challenge challenge) {
    return <String, Object?>{
      'id': challenge.id,
      'user_id': challenge.userId,
      'title': challenge.title,
      'type': challenge.type,
      'description': challenge.description,
      'difficulty': challenge.difficulty,
      'target': challenge.target,
      'progress': challenge.progress,
      'reward_xp': challenge.rewardXp,
      'is_completed': ModelCodec.boolToInt(challenge.isCompleted),
      'completed_at': ModelCodec.epochMs(challenge.completedAt),
      'created_at': ModelCodec.epochMs(challenge.createdAt),
      'updated_at': ModelCodec.epochMs(challenge.updatedAt),
    };
  }

  static Challenge fromMap(Map<String, Object?> row) {
    return Challenge(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      type: row['type'] as String,
      description: row['description'] as String,
      difficulty: row['difficulty'] as String,
      target: ModelCodec.toInt(row['target']),
      progress: ModelCodec.toInt(row['progress']),
      rewardXp: ModelCodec.toInt(row['reward_xp']),
      isCompleted: ModelCodec.intToBool(row['is_completed']),
      completedAt: ModelCodec.fromEpochMs(row['completed_at'] as int?),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
