import '../../domain/entities/sleep_log.dart';
import '../services/security/encryption_service.dart';
import 'model_codec.dart';

/// Maps [SleepLog] to and from rows in the `sleep_log` table.
class SleepLogModel {
  SleepLogModel._();

  static const String table = 'sleep_log';

  static Map<String, Object?> toMap(SleepLog log) {
    return <String, Object?>{
      'id': log.id,
      'user_id': log.userId,
      'sleep_date': ModelCodec.epochMs(log.sleepDate),
      'duration_minutes': log.durationMinutes,
      'bedtime': ModelCodec.epochMs(log.bedtime),
      'wake_time': ModelCodec.epochMs(log.wakeTime),
      'quality': log.quality,
      'note': FieldEncryption.encrypt(log.note),
      'created_at': ModelCodec.epochMs(log.createdAt),
    };
  }

  static SleepLog fromMap(Map<String, Object?> row) {
    return SleepLog(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      sleepDate:
          ModelCodec.fromEpochMs(row['sleep_date'] as int?) ?? DateTime.now(),
      durationMinutes: ModelCodec.toInt(row['duration_minutes']),
      bedtime: ModelCodec.fromEpochMs(row['bedtime'] as int?),
      wakeTime: ModelCodec.fromEpochMs(row['wake_time'] as int?),
      quality: ModelCodec.toInt(row['quality']),
      note: FieldEncryption.decrypt(row['note'] as String?),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
