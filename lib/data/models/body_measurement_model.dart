import '../../domain/entities/body_measurement.dart';
import '../services/security/encryption_service.dart';
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
      'left_arm_cm': measurement.leftArmCm,
      'right_arm_cm': measurement.rightArmCm,
      'left_thigh_cm': measurement.leftThighCm,
      'right_thigh_cm': measurement.rightThighCm,
      'left_calf_cm': measurement.leftCalfCm,
      'right_calf_cm': measurement.rightCalfCm,
      'note': FieldEncryption.encrypt(measurement.note),
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
      leftArmCm: ModelCodec.toDouble(row['left_arm_cm']),
      rightArmCm: ModelCodec.toDouble(row['right_arm_cm']),
      leftThighCm: ModelCodec.toDouble(row['left_thigh_cm']),
      rightThighCm: ModelCodec.toDouble(row['right_thigh_cm']),
      leftCalfCm: ModelCodec.toDouble(row['left_calf_cm']),
      rightCalfCm: ModelCodec.toDouble(row['right_calf_cm']),
      note: FieldEncryption.decrypt(row['note'] as String?),
      measuredAt:
          ModelCodec.fromEpochMs(row['measured_at'] as int?) ?? DateTime.now(),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
