import '../../domain/entities/body_measurement.dart';
import 'model_codec.dart';

/// Maps [BodyMeasurement] to and from rows in the `body_measurement` table.
class BodyMeasurementModel {
  BodyMeasurementModel._();

  static const String table = 'body_measurement';

  static Map<String, Object?> toMap(BodyMeasurement measurement) {
    return <String, Object?>{
      'id': measurement.id,
      'user_id': measurement.userId,
      'chest_cm': measurement.chestCm,
      'waist_cm': measurement.waistCm,
      'hip_cm': measurement.hipCm,
      'arm_cm': measurement.armCm,
      'thigh_cm': measurement.thighCm,
      'neck_cm': measurement.neckCm,
      'shoulder_cm': measurement.shoulderCm,
      'note': measurement.note,
      'measured_at': ModelCodec.epochMs(measurement.measuredAt),
      'created_at': ModelCodec.epochMs(measurement.createdAt),
    };
  }

  static BodyMeasurement fromMap(Map<String, Object?> row) {
    return BodyMeasurement(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      chestCm: ModelCodec.toDouble(row['chest_cm']),
      waistCm: ModelCodec.toDouble(row['waist_cm']),
      hipCm: ModelCodec.toDouble(row['hip_cm']),
      armCm: ModelCodec.toDouble(row['arm_cm']),
      thighCm: ModelCodec.toDouble(row['thigh_cm']),
      neckCm: ModelCodec.toDouble(row['neck_cm']),
      shoulderCm: ModelCodec.toDouble(row['shoulder_cm']),
      note: row['note'] as String?,
      measuredAt:
          ModelCodec.fromEpochMs(row['measured_at'] as int?) ?? DateTime.now(),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
