import '../../domain/entities/food_log.dart';
import 'model_codec.dart';

/// Maps [FoodLog] to and from rows in the `food_log` table.
class FoodLogModel {
  FoodLogModel._();

  static const String table = 'food_log';

  static Map<String, Object?> toMap(FoodLog log) {
    return <String, Object?>{
      'id': log.id,
      'user_id': log.userId,
      'food_item_id': log.foodItemId,
      'meal_id': log.mealId,
      'meal_type_id': log.mealTypeId,
      'quantity': log.quantity,
      'serving_size': log.servingSize,
      'calories': log.calories,
      'protein': log.protein,
      'carbs': log.carbs,
      'fat': log.fat,
      'fiber': log.fiber,
      'sugar': log.sugar,
      'logged_at': ModelCodec.epochMs(log.loggedAt),
      'created_at': ModelCodec.epochMs(log.createdAt),
    };
  }

  static FoodLog fromMap(Map<String, Object?> row) {
    return FoodLog(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      foodItemId: row['food_item_id'] as int?,
      mealId: row['meal_id'] as int?,
      mealTypeId: row['meal_type_id'] as int?,
      quantity: ModelCodec.toDouble(row['quantity']) ?? 1,
      servingSize: row['serving_size'] as String?,
      calories: ModelCodec.toDouble(row['calories']) ?? 0,
      protein: ModelCodec.toDouble(row['protein']) ?? 0,
      carbs: ModelCodec.toDouble(row['carbs']) ?? 0,
      fat: ModelCodec.toDouble(row['fat']) ?? 0,
      fiber: ModelCodec.toDouble(row['fiber']) ?? 0,
      sugar: ModelCodec.toDouble(row['sugar']) ?? 0,
      loggedAt:
          ModelCodec.fromEpochMs(row['logged_at'] as int?) ?? DateTime.now(),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
