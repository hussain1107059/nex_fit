import '../../domain/entities/reward.dart';
import 'model_codec.dart';

class RewardModel {
  RewardModel._();

  static const String table = 'reward';

  static Map<String, Object?> toMap(Reward reward) {
    return <String, Object?>{
      'id': reward.id,
      'user_id': reward.userId,
      'type': reward.type,
      'title': reward.title,
      'amount': reward.amount,
      'icon': reward.icon,
      'is_claimed': ModelCodec.boolToInt(reward.isClaimed),
      'claimed_at': ModelCodec.epochMs(reward.claimedAt),
      'created_at': ModelCodec.epochMs(reward.createdAt),
      'updated_at': ModelCodec.epochMs(reward.updatedAt),
    };
  }

  static Reward fromMap(Map<String, Object?> row) {
    return Reward(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      type: row['type'] as String,
      title: row['title'] as String,
      amount: ModelCodec.toInt(row['amount']),
      icon: row['icon'] as String?,
      isClaimed: ModelCodec.intToBool(row['is_claimed']),
      claimedAt: ModelCodec.fromEpochMs(row['claimed_at'] as int?),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
