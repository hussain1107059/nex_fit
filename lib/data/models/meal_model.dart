import '../../domain/entities/meal.dart';
import 'model_codec.dart';

/// Maps [Meal] to and from rows in the `meal` table.
class MealModel {
  MealModel._();

  static const String table = 'meal';

  static Map<String, Object?> toMap(Meal meal) {
    return <String, Object?>{
      'id': meal.id,
      'user_id': meal.userId,
      'category_id': meal.categoryId,
      'name': meal.name,
      'description': meal.description,
      'calories': meal.calories,
      'protein': meal.protein,
      'carbs': meal.carbs,
      'fat': meal.fat,
      'image': meal.image,
      'is_favorite': ModelCodec.boolToInt(meal.isFavorite),
      'created_at': ModelCodec.epochMs(meal.createdAt),
      'updated_at': ModelCodec.epochMs(meal.updatedAt),
    };
  }

  static Meal fromMap(Map<String, Object?> row) {
    return Meal(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      categoryId: row['category_id'] as int?,
      name: row['name'] as String,
      description: row['description'] as String?,
      calories: ModelCodec.toDouble(row['calories']) ?? 0,
      protein: ModelCodec.toDouble(row['protein']) ?? 0,
      carbs: ModelCodec.toDouble(row['carbs']) ?? 0,
      fat: ModelCodec.toDouble(row['fat']) ?? 0,
      image: row['image'] as String?,
      isFavorite: ModelCodec.intToBool(row['is_favorite']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
