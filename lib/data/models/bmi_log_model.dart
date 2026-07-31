import '../../domain/entities/bmi_log.dart';
import 'model_codec.dart';

/// Maps [BmiLog] to and from rows in the `bmi_log` table.
class BmiLogModel {
  BmiLogModel._();

  static const String table = 'bmi_log';

  static Map<String, Object?> toMap(BmiLog log) {
    return <String, Object?>{
      'id': log.id,
      'user_id': log.userId,
      'bmi': log.bmi,
      'weight_kg': log.weightKg,
      'height_cm': log.heightCm,
      'category': log.category,
      'logged_at': ModelCodec.epochMs(log.loggedAt),
      'created_at': ModelCodec.epochMs(log.createdAt),
    };
  }

  static BmiLog fromMap(Map<String, Object?> row) {
    return BmiLog(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      bmi: ModelCodec.toDouble(row['bmi']) ?? 0,
      weightKg: ModelCodec.toDouble(row['weight_kg']),
      heightCm: ModelCodec.toDouble(row['height_cm']),
      category: row['category'] as String?,
      loggedAt:
          ModelCodec.fromEpochMs(row['logged_at'] as int?) ?? DateTime.now(),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
