import '../../domain/entities/common_enums.dart';
import '../../domain/entities/workout.dart';
import 'model_codec.dart';

/// Maps [Workout] to and from rows in the `workout` table.
class WorkoutModel {
  WorkoutModel._();

  static const String table = 'workout';

  static Map<String, Object?> toMap(Workout workout) {
    return <String, Object?>{
      'id': workout.id,
      'user_id': workout.userId,
      'category_id': workout.categoryId,
      'name': workout.name,
      'description': workout.description,
      'difficulty': workout.difficulty?.name,
      'duration_minutes': workout.durationMinutes,
      'calories_burn': workout.caloriesBurn,
      'image': workout.image,
      'is_favorite': ModelCodec.boolToInt(workout.isFavorite),
      'is_custom': ModelCodec.boolToInt(workout.isCustom),
      'created_at': ModelCodec.epochMs(workout.createdAt),
      'updated_at': ModelCodec.epochMs(workout.updatedAt),
    };
  }

  static Workout fromMap(Map<String, Object?> row) {
    return Workout(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      categoryId: row['category_id'] as int?,
      name: row['name'] as String,
      description: row['description'] as String?,
      difficulty: Difficulty.fromName(row['difficulty'] as String?),
      durationMinutes: row['duration_minutes'] as int?,
      caloriesBurn: ModelCodec.toDouble(row['calories_burn']),
      image: row['image'] as String?,
      isFavorite: ModelCodec.intToBool(row['is_favorite']),
      isCustom: ModelCodec.intToBool(row['is_custom']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
