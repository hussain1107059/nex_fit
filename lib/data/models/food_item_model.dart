import '../../domain/entities/food_item.dart';
import 'model_codec.dart';

/// Maps [FoodItem] to and from rows in the `food_item` table.
///
/// [FoodItem.isFavorite] is a per-user derived flag (resolved from the
/// `food_favorite` join table) and is therefore not persisted here.
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
      'sodium': item.sodium,
      'potassium': item.potassium,
      'calcium': item.calcium,
      'iron': item.iron,
      'vitamin_a': item.vitaminA,
      'vitamin_c': item.vitaminC,
      'water_percentage': item.waterPercentage,
      'barcode': item.barcode,
      'image_path': item.imagePath,
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
      sodium: ModelCodec.toDouble(row['sodium']) ?? 0,
      potassium: ModelCodec.toDouble(row['potassium']) ?? 0,
      calcium: ModelCodec.toDouble(row['calcium']) ?? 0,
      iron: ModelCodec.toDouble(row['iron']) ?? 0,
      vitaminA: ModelCodec.toDouble(row['vitamin_a']) ?? 0,
      vitaminC: ModelCodec.toDouble(row['vitamin_c']) ?? 0,
      waterPercentage: ModelCodec.toDouble(row['water_percentage']) ?? 0,
      barcode: row['barcode'] as String?,
      imagePath: row['image_path'] as String?,
      isCustom: ModelCodec.intToBool(row['is_custom']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
