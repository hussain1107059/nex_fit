import '../../domain/entities/common_enums.dart';

/// BMI category for a computed BMI value.
enum BmiCategory { underweight, normal, overweight, obese }

/// Pure calculations for body composition and energy targets.
///
/// Formulas:
/// - BMI: weight(kg) / height(m)^2 (WHO cut-offs).
/// - BMR: Mifflin-St Jeor equation.
/// - Daily calories: BMR x activity multiplier (Harris-Benedict factors).
class HealthCalculator {
  HealthCalculator._();

  static const double _healthyBmiMin = 18.5;
  static const double _healthyBmiMax = 24.9;
  static const double _waterPerKgMl = 35;
  static const int _defaultStepTarget = 10000;

  /// Body mass index from metric values. Returns null when inputs are invalid.
  static double? bmi({required double? weightKg, required double? heightCm}) {
    if (weightKg == null || heightCm == null || weightKg <= 0 || heightCm <= 0) {
      return null;
    }
    final double meters = heightCm / 100;
    return weightKg / (meters * meters);
  }

  /// WHO classification of a BMI value.
  static BmiCategory classify(double bmi) {
    if (bmi < _healthyBmiMin) return BmiCategory.underweight;
    if (bmi < 25) return BmiCategory.normal;
    if (bmi < 30) return BmiCategory.overweight;
    return BmiCategory.obese;
  }

  /// Healthy weight band (min, max) in kilograms for a given height in cm.
  static ({double minKg, double maxKg})? healthyRange(double? heightCm) {
    if (heightCm == null || heightCm <= 0) return null;
    final double meters = heightCm / 100;
    final double area = meters * meters;
    return (
      minKg: _healthyBmiMin * area,
      maxKg: _healthyBmiMax * area,
    );
  }

  /// Age in whole years from a birth date.
  static int? age(DateTime? birthDate) {
    if (birthDate == null) return null;
    final DateTime now = DateTime.now();
    int years = now.year - birthDate.year;
    final bool hasBirthdayPassed =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasBirthdayPassed) years--;
    return years < 0 ? null : years;
  }

  /// Basal metabolic rate using the Mifflin-St Jeor equation.
  /// Returns null when required inputs are missing.
  static double? bmr({
    required double? weightKg,
    required double? heightCm,
    required int? age,
    required Gender? gender,
  }) {
    if (weightKg == null ||
        heightCm == null ||
        age == null ||
        gender == null ||
        weightKg <= 0 ||
        heightCm <= 0 ||
        age <= 0) {
      return null;
    }
    final double base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    return switch (gender) {
      Gender.male => base + 5,
      Gender.female => base - 161,
      Gender.other => base - 78,
    };
  }

  /// Daily calorie maintenance requirement = BMR x activity multiplier.
  static double? dailyCalories({required double? bmrValue, ActivityLevel? level}) {
    if (bmrValue == null) return null;
    return bmrValue * _activityMultiplier(level ?? ActivityLevel.moderate);
  }

  /// Suggested daily water intake in ml based on body weight.
  static int waterTargetMl(double? weightKg) {
    if (weightKg == null || weightKg <= 0) return 2000;
    final int raw = (weightKg * _waterPerKgMl).round();
    return (raw ~/ 100) * 100;
  }

  static int get defaultStepTarget => _defaultStepTarget;

  static double _activityMultiplier(ActivityLevel level) {
    return switch (level) {
      ActivityLevel.sedentary => 1.2,
      ActivityLevel.light => 1.375,
      ActivityLevel.moderate => 1.55,
      ActivityLevel.active => 1.725,
      ActivityLevel.veryActive => 1.9,
      ActivityLevel.athlete => 1.9,
    };
  }
}
