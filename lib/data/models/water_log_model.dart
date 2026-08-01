import '../../domain/entities/water_log.dart';
import 'model_codec.dart';

/// Maps [WaterLog] to and from rows in the `water_log` table.
class WaterLogModel {
  WaterLogModel._();

  static const String table = 'water_log';

  static Map<String, Object?> toMap(WaterLog log) {
    return <String, Object?>{
      'id': log.id,
      'user_id': log.userId,
      'amount_ml': log.amountMl,
      'logged_at': ModelCodec.epochMs(log.loggedAt),
      'created_at': ModelCodec.epochMs(log.createdAt),
      'note': log.note,
    };
  }

  static WaterLog fromMap(Map<String, Object?> row) {
    return WaterLog(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      amountMl: ModelCodec.toInt(row['amount_ml']),
      loggedAt:
          ModelCodec.fromEpochMs(row['logged_at'] as int?) ?? DateTime.now(),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      note: row['note'] as String?,
    );
  }
}
