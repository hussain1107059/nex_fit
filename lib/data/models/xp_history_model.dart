import '../../domain/entities/xp_history.dart';
import 'model_codec.dart';

class XpHistoryModel {
  XpHistoryModel._();

  static const String table = 'xp_history';

  static Map<String, Object?> toMap(XpHistory xpHistory) {
    return <String, Object?>{
      'id': xpHistory.id,
      'user_id': xpHistory.userId,
      'source': xpHistory.source,
      'reason': xpHistory.reason,
      'xp': xpHistory.xp,
      'total_xp': xpHistory.totalXp,
      'metadata': xpHistory.metadata,
      'created_at': ModelCodec.epochMs(xpHistory.createdAt),
    };
  }

  static XpHistory fromMap(Map<String, Object?> row) {
    return XpHistory(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      source: row['source'] as String,
      reason: row['reason'] as String,
      xp: ModelCodec.toInt(row['xp']),
      totalXp: ModelCodec.toInt(row['total_xp']),
      metadata: row['metadata'] as String?,
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
