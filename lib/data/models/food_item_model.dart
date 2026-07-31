import '../../domain/entities/food_item.dart';
import 'model_codec.dart';

/// Maps [FoodItem] to and from rows in the `food_item` table.
class FoodItemModel {
  FoodItemModel._();

  static const String table = 'food_item';

  static Map<String, Object?> toMap(FoodItem item) {
    return <String, Object?>{
      'id': item.id,
      'user_id': item.userId,
      'name': item.name,
      'brand': item.brand,
      'category': item.category,
      'serving_size': item.servingSize,
      'serving_grams': item.servingGrams,
      'calories': item.calories,
      'protein': item.protein,
      'carbs': item.carbs,
      'fat': item.fat,
      'fiber': item.fiber,
      'sugar': item.sugar,
      'is_custom': ModelCodec.boolToInt(item.isCustom),
      'created_at': ModelCodec.epochMs(item.createdAt),
    };
  }

  static FoodItem fromMap(Map<String, Object?> row) {
    return FoodItem(
      id: row['id'] as int?,
      userId: row['user_id'] as String?,
      name: row['name'] as String,
      brand: row['brand'] as String?,
      category: row['category'] as String?,
      servingSize: row['serving_size'] as String?,
      servingGrams: ModelCodec.toDouble(row['serving_grams']),
      calories: ModelCodec.toDouble(row['calories']) ?? 0,
      protein: ModelCodec.toDouble(row['protein']) ?? 0,
      carbs: ModelCodec.toDouble(row['carbs']) ?? 0,
      fat: ModelCodec.toDouble(row['fat']) ?? 0,
      fiber: ModelCodec.toDouble(row['fiber']) ?? 0,
      sugar: ModelCodec.toDouble(row['sugar']) ?? 0,
      isCustom: ModelCodec.intToBool(row['is_custom']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
