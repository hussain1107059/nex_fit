import '../../domain/entities/common_enums.dart';
import '../../domain/entities/user_profile.dart';
import 'model_codec.dart';

/// Maps [UserProfile] to and from rows in the `user_profile` table.
class UserProfileModel {
  UserProfileModel._();

  static const String table = 'user_profile';

  static Map<String, Object?> toMap(UserProfile profile) {
    return <String, Object?>{
      'user_id': profile.userId,
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
      'target_weight_kg': profile.targetWeightKg,
      'gender': profile.gender?.name,
      'birth_date': ModelCodec.epochMs(profile.birthDate),
      'activity_level': profile.activityLevel?.name,
      'fitness_goal': profile.fitnessGoal?.name,
      'country': profile.country,
      'language': profile.language,
      'photo_path': profile.photoPath,
      'target_calories': profile.targetCalories,
      'target_protein': profile.targetProtein,
      'target_carbs': profile.targetCarbs,
      'target_fat': profile.targetFat,
      'target_water_ml': profile.targetWaterMl,
      'target_steps': profile.targetSteps,
      'updated_at': ModelCodec.epochMs(profile.updatedAt),
    };
  }

  static UserProfile fromMap(Map<String, Object?> row) {
    return UserProfile(
      userId: row['user_id'] as String,
      heightCm: ModelCodec.toDouble(row['height_cm']),
      weightKg: ModelCodec.toDouble(row['weight_kg']),
      targetWeightKg: ModelCodec.toDouble(row['target_weight_kg']),
      gender: Gender.fromName(row['gender'] as String?),
      birthDate: ModelCodec.fromEpochMs(row['birth_date'] as int?),
      activityLevel: ActivityLevel.fromName(row['activity_level'] as String?),
      fitnessGoal: GoalType.fromName(row['fitness_goal'] as String?),
      country: row['country'] as String?,
      language: row['language'] as String?,
      photoPath: row['photo_path'] as String?,
      targetCalories: ModelCodec.toDouble(row['target_calories']),
      targetProtein: ModelCodec.toDouble(row['target_protein']),
      targetCarbs: ModelCodec.toDouble(row['target_carbs']),
      targetFat: ModelCodec.toDouble(row['target_fat']),
      targetWaterMl: row['target_water_ml'] as int?,
      targetSteps: row['target_steps'] as int?,
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
