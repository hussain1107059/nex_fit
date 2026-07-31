import 'package:equatable/equatable.dart';

/// Daily step count and derived metrics for the user.
class StepLog extends Equatable {
  const StepLog({
    this.id,
    required this.userId,
    required this.stepDate,
    this.steps = 0,
    this.distanceKm = 0,
    this.caloriesBurned = 0,
    required this.createdAt,
  });

  final int? id;
  final String userId;

  /// The day these steps belong to (date only, epoch milliseconds).
  final DateTime stepDate;
  final int steps;
  final double distanceKm;
  final double caloriesBurned;
  final DateTime createdAt;

  StepLog copyWith({
    int? id,
    String? userId,
    DateTime? stepDate,
    int? steps,
    double? distanceKm,
    double? caloriesBurned,
    DateTime? createdAt,
  }) {
    return StepLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      stepDate: stepDate ?? this.stepDate,
      steps: steps ?? this.steps,
      distanceKm: distanceKm ?? this.distanceKm,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, stepDate, steps, distanceKm, caloriesBurned, createdAt];
}
