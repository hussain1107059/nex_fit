import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/utils/health_calculator.dart';
import 'package:nexfit/domain/entities/common_enums.dart';

void main() {
  group('HealthCalculator.bmi', () {
    test('computes BMI from metric values', () {
      final double? value = HealthCalculator.bmi(
        weightKg: 70,
        heightCm: 175,
      );
      expect(value, closeTo(22.86, 0.01));
    });

    test('returns null for invalid inputs', () {
      expect(HealthCalculator.bmi(weightKg: null, heightCm: 175), isNull);
      expect(HealthCalculator.bmi(weightKg: 70, heightCm: 0), isNull);
      expect(HealthCalculator.bmi(weightKg: -5, heightCm: 175), isNull);
    });
  });

  group('HealthCalculator.classify', () {
    test('maps WHO cut-offs', () {
      expect(HealthCalculator.classify(17), BmiCategory.underweight);
      expect(HealthCalculator.classify(21), BmiCategory.normal);
      expect(HealthCalculator.classify(27), BmiCategory.overweight);
      expect(HealthCalculator.classify(32), BmiCategory.obese);
    });
  });

  group('HealthCalculator.healthyRange', () {
    test('returns the healthy weight band for a height', () {
      final range = HealthCalculator.healthyRange(175);
      expect(range, isNotNull);
      expect(range!.minKg, closeTo(56.66, 0.01));
      expect(range.maxKg, closeTo(76.26, 0.01));
    });

    test('returns null for an invalid height', () {
      expect(HealthCalculator.healthyRange(null), isNull);
      expect(HealthCalculator.healthyRange(0), isNull);
    });
  });

  group('HealthCalculator.age', () {
    test('computes whole years since birth', () {
      final DateTime now = DateTime.now();
      final DateTime born = DateTime(now.year - 25, now.month, now.day);
      expect(HealthCalculator.age(born), 25);
    });

    test('returns null for a future birth date', () {
      final DateTime future = DateTime.now().add(const Duration(days: 1));
      expect(HealthCalculator.age(future), isNull);
    });

    test('returns null for null', () {
      expect(HealthCalculator.age(null), isNull);
    });
  });

  group('HealthCalculator.bmr', () {
    test('computes Mifflin-St Jeor for a male', () {
      final double? value = HealthCalculator.bmr(
        weightKg: 80,
        heightCm: 180,
        age: 30,
        gender: Gender.male,
      );
      // 10*80 + 6.25*180 - 5*30 + 5
      expect(value, closeTo(1780, 0.01));
    });

    test('computes Mifflin-St Jeor for a female', () {
      final double? value = HealthCalculator.bmr(
        weightKg: 60,
        heightCm: 165,
        age: 30,
        gender: Gender.female,
      );
      // 10*60 + 6.25*165 - 5*30 - 161
      expect(value, closeTo(1320.25, 0.01));
    });

    test('returns null when inputs are missing', () {
      expect(
        HealthCalculator.bmr(
          weightKg: null,
          heightCm: 180,
          age: 30,
          gender: Gender.male,
        ),
        isNull,
      );
    });
  });

  group('HealthCalculator.dailyCalories', () {
    test('applies the activity multiplier', () {
      final double? value = HealthCalculator.dailyCalories(
        bmrValue: 1775,
        level: ActivityLevel.moderate,
      );
      expect(value, closeTo(1775 * 1.55, 0.01));
    });

    test('returns null for a null BMR', () {
      expect(HealthCalculator.dailyCalories(bmrValue: null), isNull);
    });
  });

  group('HealthCalculator.waterTargetMl', () {
    test('derives target from body weight', () {
      expect(HealthCalculator.waterTargetMl(70), 2400);
    });

    test('falls back to a default for invalid input', () {
      expect(HealthCalculator.waterTargetMl(null), 2000);
      expect(HealthCalculator.waterTargetMl(0), 2000);
    });
  });

  group('HealthCalculator.idealWeightKg', () {
    test('uses the Devine formula for a male', () {
      final double? value = HealthCalculator.idealWeightKg(
        heightCm: 175,
        gender: Gender.male,
      );
      // 50 + 2.3 * (175/2.54 - 60)
      expect(value, closeTo(70.46, 0.01));
    });

    test('falls back to healthy BMI midpoint for unknown gender', () {
      final double? value = HealthCalculator.idealWeightKg(
        heightCm: 175,
        gender: null,
      );
      expect(value, closeTo(21.75 * (1.75 * 1.75), 0.01));
    });

    test('returns null for an invalid height', () {
      expect(HealthCalculator.idealWeightKg(heightCm: null, gender: null), isNull);
    });
  });

  group('HealthCalculator.bodyFatNavy', () {
    test('estimates body fat for a male', () {
      final double? value = HealthCalculator.bodyFatNavy(
        gender: Gender.male,
        heightCm: 180,
        neckCm: 40,
        waistCm: 85,
        hipCm: null,
      );
      expect(value, isNotNull);
      expect(value, inInclusiveRange(1, 75));
    });

    test('returns null when a required measurement is missing', () {
      expect(
        HealthCalculator.bodyFatNavy(
          gender: Gender.male,
          heightCm: 180,
          neckCm: null,
          waistCm: 85,
          hipCm: null,
        ),
        isNull,
      );
    });
  });

  group('HealthCalculator.bodyFatBmi', () {
    test('estimates body fat from BMI (Deurenberg)', () {
      final double? value = HealthCalculator.bodyFatBmi(
        bmi: 22.9,
        age: 30,
        gender: Gender.female,
      );
      // 1.20*22.9 + 0.23*30 - 10.8*0 - 5.4
      expect(value, closeTo(29.0, 0.1));
    });

    test('returns null for invalid inputs', () {
      expect(
        HealthCalculator.bodyFatBmi(bmi: null, age: 30, gender: Gender.male),
        isNull,
      );
    });
  });

  group('HealthCalculator.leanBodyMass', () {
    test('computes lean mass from weight and body fat', () {
      final double? value = HealthCalculator.leanBodyMass(
        weightKg: 80,
        bodyFatPercent: 20,
      );
      expect(value, closeTo(64, 0.01));
    });

    test('returns null for invalid inputs', () {
      expect(
        HealthCalculator.leanBodyMass(weightKg: null, bodyFatPercent: 20),
        isNull,
      );
    });
  });
}
