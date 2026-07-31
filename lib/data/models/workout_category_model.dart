import '../../domain/entities/workout_category.dart';
import 'model_codec.dart';

/// Maps [WorkoutCategory] to and from rows in the `workout_category` table.
class WorkoutCategoryModel {
  WorkoutCategoryModel._();

  static const String table = 'workout_category';

  static Map<String, Object?> toMap(WorkoutCategory category) {
    return <String, Object?>{
      'id': category.id,
      'name': category.name,
      'slug': category.slug,
      'description': category.description,
      'icon': category.icon,
      'color': category.color,
      'sort_order': category.sortOrder,
      'created_at': ModelCodec.epochMs(category.createdAt),
    };
  }

  static WorkoutCategory fromMap(Map<String, Object?> row) {
    return WorkoutCategory(
      id: row['id'] as int?,
      name: row['name'] as String,
      slug: row['slug'] as String,
      description: row['description'] as String?,
      icon: row['icon'] as String?,
      color: row['color'] as int?,
      sortOrder: ModelCodec.toInt(row['sort_order']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
