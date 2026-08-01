import '../entities/meal_item.dart';

/// Contract for managing the foods inside saved meal templates.
abstract interface class MealItemRepository {
  Future<int> insert(MealItem item);

  Future<void> insertAll(List<MealItem> items);

  Future<void> update(MealItem item);

  Future<List<MealItem>> getByMeal(int mealId);

  Future<List<MealItem>> getByMeals(List<int> mealIds);

  Future<void> deleteByMeal(int mealId);

  Future<void> delete(int id);
}
