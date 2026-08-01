import 'package:equatable/equatable.dart';

/// Aggregated figures for a [ReportPeriod] window.
class AnalyticsSummary extends Equatable {
  const AnalyticsSummary({
    this.workoutCount = 0,
    this.workoutDays = 0,
    this.workoutMinutes = 0,
    this.caloriesBurned = 0,
    this.caloriesConsumed = 0,
    this.waterMl = 0,
    this.steps = 0,
    this.sleepMinutes = 0,
    this.activeDays = 0,
    this.weightStartKg,
    this.weightEndKg,
    this.bmiStart,
    this.bmiEnd,
  });

  final int workoutCount;
  final int workoutDays;
  final double workoutMinutes;
  final double caloriesBurned;
  final double caloriesConsumed;
  final int waterMl;
  final int steps;
  final double sleepMinutes;
  final int activeDays;
  final double? weightStartKg;
  final double? weightEndKg;
  final double? bmiStart;
  final double? bmiEnd;

  /// Signed change between the first and last weight in the window.
  double? get weightChangeKg {
    if (weightStartKg == null || weightEndKg == null) return null;
    return weightEndKg! - weightStartKg!;
  }

  /// Signed change between the first and last BMI in the window.
  double? get bmiChange {
    if (bmiStart == null || bmiEnd == null) return null;
    return bmiEnd! - bmiStart!;
  }

  /// Average calories burned per tracked day.
  double get avgCaloriesPerDay =>
      activeDays == 0 ? 0 : caloriesBurned / activeDays;

  /// Average workout minutes per tracked day.
  double get avgWorkoutMinutesPerDay =>
      activeDays == 0 ? 0 : workoutMinutes / activeDays;

  /// Average steps per tracked day.
  int get avgStepsPerDay =>
      activeDays == 0 ? 0 : (steps / activeDays).round();

  /// Average water (ml) per tracked day.
  int get avgWaterMlPerDay =>
      activeDays == 0 ? 0 : (waterMl / activeDays).round();

  /// Average sleep (hours) per tracked day.
  double get avgSleepHoursPerDay =>
      activeDays == 0 ? 0 : sleepMinutes / 60 / activeDays;

  @override
  List<Object?> get props => [
        workoutCount,
        workoutDays,
        workoutMinutes,
        caloriesBurned,
        caloriesConsumed,
        waterMl,
        steps,
        sleepMinutes,
        activeDays,
        weightStartKg,
        weightEndKg,
        bmiStart,
        bmiEnd,
      ];
}
