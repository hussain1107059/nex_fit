import 'package:equatable/equatable.dart';

/// A BMI snapshot computed from height and weight at a point in time.
class BmiLog extends Equatable {
  const BmiLog({
    this.id,
    required this.userId,
    required this.bmi,
    this.weightKg,
    this.heightCm,
    this.category,
    required this.loggedAt,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final double bmi;
  final double? weightKg;
  final double? heightCm;
  final String? category;
  final DateTime loggedAt;
  final DateTime createdAt;

  BmiLog copyWith({
    int? id,
    String? userId,
    double? bmi,
    double? weightKg,
    double? heightCm,
    String? category,
    DateTime? loggedAt,
    DateTime? createdAt,
  }) {
    return BmiLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bmi: bmi ?? this.bmi,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      category: category ?? this.category,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, bmi, weightKg, heightCm, category, loggedAt, createdAt];
}
