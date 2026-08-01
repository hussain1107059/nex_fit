import '../../domain/entities/weight_log.dart';
import '../services/security/encryption_service.dart';
import 'model_codec.dart';

/// Maps [WeightLog] to and from rows in the `weight_log` table.
class WeightLogModel {
  WeightLogModel._();

  static const String table = 'weight_log';

  static Map<String, Object?> toMap(WeightLog log) {
    return <String, Object?>{
      'id': log.id,
      'user_id': log.userId,
      'weight_kg': log.weightKg,
      'note': FieldEncryption.encrypt(log.note),
      'logged_at': ModelCodec.epochMs(log.loggedAt),
      'created_at': ModelCodec.epochMs(log.createdAt),
    };
  }

  static WeightLog fromMap(Map<String, Object?> row) {
    return WeightLog(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      weightKg: ModelCodec.toDouble(row['weight_kg']) ?? 0,
      note: FieldEncryption.decrypt(row['note'] as String?),
      loggedAt:
          ModelCodec.fromEpochMs(row['logged_at'] as int?) ?? DateTime.now(),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
