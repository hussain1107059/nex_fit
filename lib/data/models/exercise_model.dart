import '../../domain/entities/common_enums.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_category.dart';
import 'model_codec.dart';

/// Maps [Exercise] to and from rows in the `exercise` table.
class ExerciseModel {
  ExerciseModel._();

  static const String table = 'exercise';

  /// Text lists are persisted as newline-joined strings.
  static String? encodeList(List<String>? values) {
    if (values == null || values.isEmpty) return null;
    return values.join('\n');
  }

  static List<String> decodeList(Object? value) {
    if (value is! String || value.isEmpty) return const <String>[];
    return value
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
  }

  static Map<String, Object?> toMap(Exercise exercise) {
    return <String, Object?>{
      'id': exercise.id,
      'user_id': exercise.userId,
      'name': exercise.name,
      'scientific_name': exercise.scientificName,
      'description': exercise.description,
      'instructions': exercise.instructions,
      'body_part': exercise.bodyPart,
      'secondary_muscle': exercise.secondaryMuscle,
      'equipment': exercise.equipment,
      'difficulty': exercise.difficulty?.name,
      'category': exercise.category?.name,
      'image': exercise.image,
      'gif_path': exercise.gifPath,
      'calories_per_minute': exercise.caloriesPerMinute,
      'estimated_calories': exercise.estimatedCalories,
      'duration_seconds': exercise.durationSeconds,
      'sets': exercise.sets,
      'reps': exercise.reps,
      'rest_seconds': exercise.restSeconds,
      'tips': encodeList(exercise.tips),
      'common_mistakes': encodeList(exercise.commonMistakes),
      'safety_instructions': encodeList(exercise.safetyInstructions),
      'is_custom': ModelCodec.boolToInt(exercise.isCustom),
      'created_at': ModelCodec.epochMs(exercise.createdAt),
    };
  }

  static Exercise fromMap(Map<String, Object?> row) {
    return Exercise(
      id: row['id'] as int?,
      userId: row['user_id'] as String?,
      name: row['name'] as String,
      scientificName: row['scientific_name'] as String?,
      description: row['description'] as String?,
      instructions: row['instructions'] as String?,
      bodyPart: row['body_part'] as String?,
      secondaryMuscle: row['secondary_muscle'] as String?,
      equipment: row['equipment'] as String?,
      difficulty: Difficulty.fromName(row['difficulty'] as String?),
      category: ExerciseCategory.fromName(row['category'] as String?),
      image: row['image'] as String?,
      gifPath: row['gif_path'] as String?,
      caloriesPerMinute: ModelCodec.toDouble(row['calories_per_minute']),
      estimatedCalories: ModelCodec.toDouble(row['estimated_calories']),
      durationSeconds: ModelCodec.toInt(row['duration_seconds']),
      sets: ModelCodec.toInt(row['sets']),
      reps: ModelCodec.toInt(row['reps']),
      restSeconds: ModelCodec.toInt(row['rest_seconds']),
      tips: decodeList(row['tips']),
      commonMistakes: decodeList(row['common_mistakes']),
      safetyInstructions: decodeList(row['safety_instructions']),
      isCustom: ModelCodec.intToBool(row['is_custom']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
