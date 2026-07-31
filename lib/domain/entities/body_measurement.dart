import 'package:equatable/equatable.dart';

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
    this.note,
    required this.measuredAt,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final double? chestCm;
  final double? waistCm;
  final double? hipCm;
  final double? armCm;
  final double? thighCm;
  final double? neckCm;
  final double? shoulderCm;
  final String? note;
  final DateTime measuredAt;
  final DateTime createdAt;

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
        note,
        measuredAt,
        createdAt,
      ];
}
