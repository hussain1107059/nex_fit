import '../../domain/entities/meal_category.dart';
import 'model_codec.dart';

/// Maps [MealCategory] to and from rows in the `meal_category` table.
class MealCategoryModel {
  MealCategoryModel._();

  static const String table = 'meal_category';

  static Map<String, Object?> toMap(MealCategory category) {
    return <String, Object?>{
      'id': category.id,
      'name': category.name,
      'slug': category.slug,
      'icon': category.icon,
      'sort_order': category.sortOrder,
      'created_at': ModelCodec.epochMs(category.createdAt),
    };
  }

  static MealCategory fromMap(Map<String, Object?> row) {
    return MealCategory(
      id: row['id'] as int?,
      name: row['name'] as String,
      slug: row['slug'] as String,
      icon: row['icon'] as String?,
      sortOrder: ModelCodec.toInt(row['sort_order']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
