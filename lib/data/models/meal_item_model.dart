import '../../domain/entities/meal_item.dart';
import 'model_codec.dart';

/// Maps [MealItem] to and from rows in the `meal_item` table.
class MealItemModel {
  MealItemModel._();

  static const String table = 'meal_item';

  static Map<String, Object?> toMap(MealItem item) {
    return <String, Object?>{
      'id': item.id,
      'meal_id': item.mealId,
      'food_item_id': item.foodItemId,
      'quantity': item.quantity,
      'sort_order': item.sortOrder,
    };
  }

  static MealItem fromMap(Map<String, Object?> row) {
    return MealItem(
      id: row['id'] as int?,
      mealId: row['meal_id'] as int,
      foodItemId: row['food_item_id'] as int,
      quantity: ModelCodec.toDouble(row['quantity']) ?? 1,
      sortOrder: ModelCodec.toInt(row['sort_order']),
    );
  }
}
