import 'package:equatable/equatable.dart';

import '../../core/utils/health_calculator.dart';
import 'bmi_log.dart';
import 'body_measurement.dart';
import 'common_enums.dart';
import 'user_profile.dart';
import 'weight_log.dart';

/// Everything the weight tracker screen needs to render: the weight log,
/// the linked profile and the computed body composition metrics.
class WeightOverview extends Equatable {
  const WeightOverview({
    required this.logs,
    this.profile,
    this.latestBmi,
    this.latestMeasurement,
  });

  /// Weight entries sorted oldest → newest.
  final List<WeightLog> logs;

  /// The user's physical profile (height, gender, targets).
  final UserProfile? profile;

  /// The most recent stored BMI snapshot, if any.
  final BmiLog? latestBmi;

  /// The most recent body measurement (used for body fat estimation).
  final BodyMeasurement? latestMeasurement;

  bool get hasEntries => logs.isNotEmpty;

  int get entriesCount => logs.length;

  WeightLog? get startWeight => logs.isEmpty ? null : logs.first;

  WeightLog? get latestWeight => logs.isEmpty ? null : logs.last;

  double? get goalWeightKg => profile?.targetWeightKg;

  double? get heightCm => profile?.heightCm;

  Gender? get gender => profile?.gender;

  int? get age => HealthCalculator.age(profile?.birthDate);

  ActivityLevel? get activityLevel => profile?.activityLevel;

  double? get bmi => HealthCalculator.bmi(
        weightKg: latestWeight?.weightKg,
        heightCm: heightCm,
      );

  BmiCategory? get bmiCategory {
    final double? value = bmi;
    return value == null ? null : HealthCalculator.classify(value);
  }

  ({double minKg, double maxKg})? get healthyRange =>
      HealthCalculator.healthyRange(heightCm);

  double? get idealWeightKg =>
      HealthCalculator.idealWeightKg(heightCm: heightCm, gender: gender);

  double? get bmr => HealthCalculator.bmr(
        weightKg: latestWeight?.weightKg,
        heightCm: heightCm,
        age: age,
        gender: gender,
      );

  /// Daily maintenance calories (profile target, else BMR x activity).
  double? get dailyCalories {
    if (profile?.targetCalories != null) return profile!.targetCalories;
    return HealthCalculator.dailyCalories(
      bmrValue: bmr,
      level: activityLevel,
    );
  }

  /// Estimated body fat percentage. Prefers the Navy circumference method
  /// when the latest measurement carries neck/waist/hip, otherwise falls back
  /// to the BMI based estimate.
  double? get bodyFatPercent {
    final double? navy = HealthCalculator.bodyFatNavy(
      gender: gender,
      heightCm: heightCm,
      neckCm: latestMeasurement?.neckCm,
      waistCm: latestMeasurement?.waistCm,
      hipCm: latestMeasurement?.hipCm,
    );
    if (navy != null) return navy;
    return HealthCalculator.bodyFatBmi(
      bmi: bmi,
      age: age,
      gender: gender,
    );
  }

  double? get leanBodyMassKg => HealthCalculator.leanBodyMass(
        weightKg: latestWeight?.weightKg,
        bodyFatPercent: bodyFatPercent,
      );

  /// Change between the newest and oldest entry (kg). Negative = lost.
  double? get weightDifference {
    if (!hasEntries || logs.length < 2) return null;
    return latestWeight!.weightKg - startWeight!.weightKg;
  }

  /// How far the user has travelled toward the target weight (0..1).
  /// 1.0 when the goal is reached. 0 when no goal or no data.
  double get targetProgress {
    final double? goal = goalWeightKg;
    final double? start = startWeight?.weightKg;
    final double? current = latestWeight?.weightKg;
    if (goal == null || start == null || current == null) return 0;
    final double range = goal - start;
    if (range.abs() < 0.0001) return 1;
    return ((current - start) / range).clamp(0.0, 1.0);
  }

  /// Difference between the current weight and the goal (kg). Positive means
  /// above goal (still needs to lose/gain to reach it).
  double? get remainingToGoal {
    final double? goal = goalWeightKg;
    final double? current = latestWeight?.weightKg;
    if (goal == null || current == null) return null;
    return current - goal;
  }

  @override
  List<Object?> get props => [
        logs,
        profile,
        latestBmi,
        latestMeasurement,
      ];
}
