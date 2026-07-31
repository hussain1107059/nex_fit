import 'package:equatable/equatable.dart';

/// Aggregated progress for a single calendar day (unique per user + date).
class DailyProgress extends Equatable {
  const DailyProgress({
    this.id,
    required this.userId,
    required this.progressDate,
    this.steps = 0,
    this.waterMl = 0,
    this.caloriesConsumed = 0,
    this.caloriesBurned = 0,
    this.workoutMinutes = 0,
    this.sleepMinutes = 0,
    this.weightKg,
    this.isGoalMet = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;

  /// The day this progress belongs to (date only, epoch milliseconds).
  final DateTime progressDate;
  final int steps;
  final int waterMl;
  final double caloriesConsumed;
  final double caloriesBurned;
  final int workoutMinutes;
  final int sleepMinutes;
  final double? weightKg;
  final bool isGoalMet;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyProgress copyWith({
    int? id,
    String? userId,
    DateTime? progressDate,
    int? steps,
    int? waterMl,
    double? caloriesConsumed,
    double? caloriesBurned,
    int? workoutMinutes,
    int? sleepMinutes,
    double? weightKg,
    bool? isGoalMet,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      progressDate: progressDate ?? this.progressDate,
      steps: steps ?? this.steps,
      waterMl: waterMl ?? this.waterMl,
      caloriesConsumed: caloriesConsumed ?? this.caloriesConsumed,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      workoutMinutes: workoutMinutes ?? this.workoutMinutes,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      weightKg: weightKg ?? this.weightKg,
      isGoalMet: isGoalMet ?? this.isGoalMet,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        progressDate,
        steps,
        waterMl,
        caloriesConsumed,
        caloriesBurned,
        workoutMinutes,
        sleepMinutes,
        weightKg,
        isGoalMet,
        createdAt,
        updatedAt,
      ];
}
