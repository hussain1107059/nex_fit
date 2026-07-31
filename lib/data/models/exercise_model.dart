import '../../domain/entities/common_enums.dart';
import '../../domain/entities/exercise.dart';
import 'model_codec.dart';

/// Maps [Exercise] to and from rows in the `exercise` table.
class ExerciseModel {
  ExerciseModel._();

  static const String table = 'exercise';

  static Map<String, Object?> toMap(Exercise exercise) {
    return <String, Object?>{
      'id': exercise.id,
      'user_id': exercise.userId,
      'name': exercise.name,
      'description': exercise.description,
      'instructions': exercise.instructions,
      'body_part': exercise.bodyPart,
      'equipment': exercise.equipment,
      'difficulty': exercise.difficulty?.name,
      'image': exercise.image,
      'calories_per_minute': exercise.caloriesPerMinute,
      'is_custom': ModelCodec.boolToInt(exercise.isCustom),
      'created_at': ModelCodec.epochMs(exercise.createdAt),
    };
  }

  static Exercise fromMap(Map<String, Object?> row) {
    return Exercise(
      id: row['id'] as int?,
      userId: row['user_id'] as String?,
      name: row['name'] as String,
      description: row['description'] as String?,
      instructions: row['instructions'] as String?,
      bodyPart: row['body_part'] as String?,
      equipment: row['equipment'] as String?,
      difficulty: Difficulty.fromName(row['difficulty'] as String?),
      image: row['image'] as String?,
      caloriesPerMinute: ModelCodec.toDouble(row['calories_per_minute']),
      isCustom: ModelCodec.intToBool(row['is_custom']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
