import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// Extended profile of the authenticated user with physical details and
/// daily nutrition/activity targets.
class UserProfile extends Equatable {
  const UserProfile({
    required this.userId,
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
    this.gender,
    this.birthDate,
    this.activityLevel,
    this.fitnessGoal,
    this.country,
    this.language,
    this.timezone,
    this.photoPath,
    this.targetCalories,
    this.targetProtein,
    this.targetCarbs,
    this.targetFat,
    this.targetWaterMl,
    this.targetSteps,
    required this.updatedAt,
  });

  final String userId;
  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;
  final Gender? gender;
  final DateTime? birthDate;
  final ActivityLevel? activityLevel;
  final GoalType? fitnessGoal;
  final String? country;
  final String? language;
  final String? timezone;
  final String? photoPath;
  final double? targetCalories;
  final double? targetProtein;
  final double? targetCarbs;
  final double? targetFat;
  final int? targetWaterMl;
  final int? targetSteps;
  final DateTime updatedAt;

  UserProfile copyWith({
    String? userId,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    Gender? gender,
    DateTime? birthDate,
    ActivityLevel? activityLevel,
    GoalType? fitnessGoal,
    String? country,
    String? language,
    String? timezone,
    String? photoPath,
    double? targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    int? targetWaterMl,
    int? targetSteps,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      activityLevel: activityLevel ?? this.activityLevel,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      country: country ?? this.country,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      photoPath: photoPath ?? this.photoPath,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFat: targetFat ?? this.targetFat,
      targetWaterMl: targetWaterMl ?? this.targetWaterMl,
      targetSteps: targetSteps ?? this.targetSteps,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        heightCm,
        weightKg,
        targetWeightKg,
        gender,
        birthDate,
        activityLevel,
        fitnessGoal,
        country,
        language,
        timezone,
        photoPath,
        targetCalories,
        targetProtein,
        targetCarbs,
        targetFat,
        targetWaterMl,
        targetSteps,
        updatedAt,
      ];
}
