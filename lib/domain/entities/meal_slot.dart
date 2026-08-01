import 'package:equatable/equatable.dart';

import 'food_log_entry.dart';
import 'meal_category.dart';

/// A meal slot of the day (Breakfast, Lunch, ...) with its logged foods and
/// the aggregated macro snapshot of that slot.
class MealSlot extends Equatable {
  const MealSlot({
    required this.category,
    this.items = const <FoodLogEntry>[],
  });

  final MealCategory category;

  /// Logged foods sorted by the time they were added.
  final List<FoodLogEntry> items;

  double get calories =>
      items.fold(0, (double sum, FoodLogEntry entry) => sum + entry.calories);

  double get protein =>
      items.fold(0, (double sum, FoodLogEntry entry) => sum + entry.protein);

  double get carbs =>
      items.fold(0, (double sum, FoodLogEntry entry) => sum + entry.carbs);

  double get fat =>
      items.fold(0, (double sum, FoodLogEntry entry) => sum + entry.fat);

  int get itemCount => items.length;

  bool get isEmpty => items.isEmpty;

  MealSlot copyWith({MealCategory? category, List<FoodLogEntry>? items}) {
    return MealSlot(
      category: category ?? this.category,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [category, items];
}
