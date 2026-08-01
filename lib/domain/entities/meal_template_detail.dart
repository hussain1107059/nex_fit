import 'package:equatable/equatable.dart';

import 'food_item.dart';
import 'meal.dart';
import 'meal_category.dart';
import 'meal_item.dart';

/// A saved meal template enriched with its component foods.
class MealTemplateDetail extends Equatable {
  const MealTemplateDetail({
    required this.meal,
    this.category,
    this.items = const <MealItem>[],
    this.foods = const <FoodItem>[],
  });

  final Meal meal;
  final MealCategory? category;
  final List<MealItem> items;
  final List<FoodItem> foods;

  /// Calories of the template computed from its component foods.
  double get calories {
    double total = 0;
    for (int index = 0; index < items.length; index++) {
      final FoodItem? food = _foodFor(index);
      if (food != null) total += food.calories * items[index].quantity;
    }
    return total;
  }

  double get protein => _macro((FoodItem food, double quantity) =>
      food.protein * quantity);

  double get carbs =>
      _macro((FoodItem food, double quantity) => food.carbs * quantity);

  double get fat =>
      _macro((FoodItem food, double quantity) => food.fat * quantity);

  double _macro(double Function(FoodItem food, double quantity) selector) {
    double total = 0;
    for (int index = 0; index < items.length; index++) {
      final FoodItem? food = _foodFor(index);
      if (food != null) total += selector(food, items[index].quantity);
    }
    return total;
  }

  FoodItem? _foodFor(int index) {
    final MealItem item = items[index];
    for (final FoodItem food in foods) {
      if (food.id == item.foodItemId) return food;
    }
    return null;
  }

  @override
  List<Object?> get props => [meal, category, items, foods];
}
