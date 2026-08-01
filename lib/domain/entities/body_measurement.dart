import 'package:equatable/equatable.dart';

/// The body parts tracked by the body measurement module.
enum MeasurementType {
  chest,
  waist,
  hip,
  neck,
  leftArm,
  rightArm,
  leftThigh,
  rightThigh,
  leftCalf,
  rightCalf;

  static MeasurementType fromName(String? value) {
    return MeasurementType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => MeasurementType.chest,
    );
  }

  /// Reads this part's value (cm) from a [BodyMeasurement].
  double? read(BodyMeasurement measurement) {
    return switch (this) {
      MeasurementType.chest => measurement.chestCm,
      MeasurementType.waist => measurement.waistCm,
      MeasurementType.hip => measurement.hipCm,
      MeasurementType.neck => measurement.neckCm,
      MeasurementType.leftArm => measurement.leftArmCm,
      MeasurementType.rightArm => measurement.rightArmCm,
      MeasurementType.leftThigh => measurement.leftThighCm,
      MeasurementType.rightThigh => measurement.rightThighCm,
      MeasurementType.leftCalf => measurement.leftCalfCm,
      MeasurementType.rightCalf => measurement.rightCalfCm,
    };
  }

  /// Returns a copy of [measurement] with this part set to [value] (cm).
  BodyMeasurement withValue(BodyMeasurement measurement, double? value) {
    return switch (this) {
      MeasurementType.chest => measurement.copyWith(chestCm: value),
      MeasurementType.waist => measurement.copyWith(waistCm: value),
      MeasurementType.hip => measurement.copyWith(hipCm: value),
      MeasurementType.neck => measurement.copyWith(neckCm: value),
      MeasurementType.leftArm => measurement.copyWith(leftArmCm: value),
      MeasurementType.rightArm => measurement.copyWith(rightArmCm: value),
      MeasurementType.leftThigh => measurement.copyWith(leftThighCm: value),
      MeasurementType.rightThigh => measurement.copyWith(rightThighCm: value),
      MeasurementType.leftCalf => measurement.copyWith(leftCalfCm: value),
      MeasurementType.rightCalf => measurement.copyWith(rightCalfCm: value),
    };
  }
}

/// Circumference measurements of a body part taken at a point in time.
class BodyMeasurement extends Equatable {
  const BodyMeasurement({
    this.id,
    required this.userId,
    this.chestCm,
    this.waistCm,
    this.hipCm,
    this.armCm,
    this.thighCm,
    this.neckCm,
    this.shoulderCm,
    this.leftArmCm,
    this.rightArmCm,
    this.leftThighCm,
    this.rightThighCm,
    this.leftCalfCm,
    this.rightCalfCm,
    this.note,
    required this.measuredAt,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final double? chestCm;
  final double? waistCm;
  final double? hipCm;

  /// Legacy single-arm measurement (kept for backward compatibility).
  final double? armCm;

  /// Legacy single-thigh measurement (kept for backward compatibility).
  final double? thighCm;

  final double? neckCm;
  final double? shoulderCm;
  final double? leftArmCm;
  final double? rightArmCm;
  final double? leftThighCm;
  final double? rightThighCm;
  final double? leftCalfCm;
  final double? rightCalfCm;
  final String? note;
  final DateTime measuredAt;
  final DateTime createdAt;

  /// True when no circumference value is recorded.
  bool get isEmpty =>
      chestCm == null &&
      waistCm == null &&
      hipCm == null &&
      armCm == null &&
      thighCm == null &&
      neckCm == null &&
      shoulderCm == null &&
      leftArmCm == null &&
      rightArmCm == null &&
      leftThighCm == null &&
      rightThighCm == null &&
      leftCalfCm == null &&
      rightCalfCm == null;

  /// The first measurement type that has a recorded value, if any.
  MeasurementType? get firstFilledType {
    for (final MeasurementType type in MeasurementType.values) {
      if (type.read(this) != null) return type;
    }
    return null;
  }

  BodyMeasurement copyWith({
    int? id,
    String? userId,
    double? chestCm,
    double? waistCm,
    double? hipCm,
    double? armCm,
    double? thighCm,
    double? neckCm,
    double? shoulderCm,
    double? leftArmCm,
    double? rightArmCm,
    double? leftThighCm,
    double? rightThighCm,
    double? leftCalfCm,
    double? rightCalfCm,
    String? note,
    DateTime? measuredAt,
    DateTime? createdAt,
  }) {
    return BodyMeasurement(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      chestCm: chestCm ?? this.chestCm,
      waistCm: waistCm ?? this.waistCm,
      hipCm: hipCm ?? this.hipCm,
      armCm: armCm ?? this.armCm,
      thighCm: thighCm ?? this.thighCm,
      neckCm: neckCm ?? this.neckCm,
      shoulderCm: shoulderCm ?? this.shoulderCm,
      leftArmCm: leftArmCm ?? this.leftArmCm,
      rightArmCm: rightArmCm ?? this.rightArmCm,
      leftThighCm: leftThighCm ?? this.leftThighCm,
      rightThighCm: rightThighCm ?? this.rightThighCm,
      leftCalfCm: leftCalfCm ?? this.leftCalfCm,
      rightCalfCm: rightCalfCm ?? this.rightCalfCm,
      note: note ?? this.note,
      measuredAt: measuredAt ?? this.measuredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        chestCm,
        waistCm,
        hipCm,
        armCm,
        thighCm,
        neckCm,
        shoulderCm,
        leftArmCm,
        rightArmCm,
        leftThighCm,
        rightThighCm,
        leftCalfCm,
        rightCalfCm,
        note,
        measuredAt,
        createdAt,
      ];
}
