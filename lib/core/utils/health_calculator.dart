import 'dart:math' as math;

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

  /// US Navy method constants (circumference based body fat estimation).
  static const double _navyMaleA = 86.010;
  static const double _navyMaleB = 70.041;
  static const double _navyMaleC = 36.76;
  static const double _navyFemaleA = 163.205;
  static const double _navyFemaleB = 97.684;
  static const double _navyFemaleC = 78.387;

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

  /// Ideal body weight using the Devine formula (kg).
  ///
  /// Men: 50 kg + 2.3 kg per inch over 5 ft. Women: 45.5 kg + 2.3 kg per
  /// inch over 5 ft. Falls back to the healthy-BMI midpoint for unspecified
  /// gender so every height still gets a sensible target.
  static double? idealWeightKg({
    required double? heightCm,
    required Gender? gender,
  }) {
    if (heightCm == null || heightCm <= 0) return null;
    if (gender == null || gender == Gender.other) {
      final double meters = heightCm / 100;
      return 21.75 * meters * meters;
    }
    final double base = gender == Gender.male ? 50.0 : 45.5;
    final double inchesOver = (heightCm / 2.54) - 60;
    return base + 2.3 * (inchesOver < 0 ? 0 : inchesOver);
  }

  /// Body fat percentage using the US Navy circumference method.
  ///
  /// Needs height plus neck (and waist for both genders; hip additionally for
  /// women). Returns null when any required input is missing.
  static double? bodyFatNavy({
    required Gender? gender,
    required double? heightCm,
    required double? neckCm,
    required double? waistCm,
    required double? hipCm,
  }) {
    if (gender == null ||
        heightCm == null ||
        heightCm <= 0 ||
        neckCm == null ||
        neckCm <= 0 ||
        waistCm == null ||
        waistCm <= 0) {
      return null;
    }
    if (gender == Gender.female && (hipCm == null || hipCm <= 0)) return null;

    final double height = heightCm;
    final double neck = neckCm;
    final double waist = waistCm;
    final double? hip = hipCm;

    final double logHeight = _log10(height);
    final double bodyFat = switch (gender) {
      Gender.male =>
        _navyMaleA * _log10(waist - neck) - _navyMaleB * logHeight +
            _navyMaleC,
      Gender.female =>
        _navyFemaleA * _log10(waist + hip! - neck) -
            _navyFemaleB * logHeight -
            _navyFemaleC,
      Gender.other => _log10BMI(waist, neck, hip, height),
    };
    return bodyFat.clamp(1.0, 75.0);
  }

  /// Body fat percentage estimated from BMI (Deurenberg equation).
  ///
  /// Used as a fallback when circumference data is unavailable.
  static double? bodyFatBmi({
    required double? bmi,
    required int? age,
    required Gender? gender,
  }) {
    if (bmi == null || bmi <= 0 || age == null || age <= 0) return null;
    final double sex = switch (gender) {
      Gender.male => 1.0,
      Gender.female => 0.0,
      Gender.other => 0.5,
      null => 0.5,
    };
    final double bodyFat = 1.20 * bmi + 0.23 * age - 10.8 * sex - 5.4;
    return bodyFat.clamp(1.0, 75.0);
  }

  /// Lean body mass in kg for a given weight and body fat percentage.
  static double? leanBodyMass({
    required double? weightKg,
    required double? bodyFatPercent,
  }) {
    if (weightKg == null || weightKg <= 0 || bodyFatPercent == null) {
      return null;
    }
    return weightKg * (1 - bodyFatPercent / 100);
  }

  static double _log10(double value) {
    if (value <= 0) return 0;
    return math.log(value) / math.log(10);
  }

  static double _log10BMI(
    double waistCm,
    double neckCm,
    double? hipCm,
    double heightCm,
  ) {
    // Gender-neutral blend for the 'other' gender (average of the two).
    final double hip = hipCm ?? waistCm;
    final double male = _navyMaleA * _log10(waistCm - neckCm) -
        _navyMaleB * _log10(heightCm) +
        _navyMaleC;
    final double female = _navyFemaleA * _log10(waistCm + hip - neckCm) -
        _navyFemaleB * _log10(heightCm) -
        _navyFemaleC;
    return (male + female) / 2;
  }

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
