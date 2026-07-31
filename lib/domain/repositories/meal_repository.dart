import '../entities/meal.dart';

/// Contract for managing a user's meals.
abstract interface class MealRepository {
  Future<int> insert(Meal meal);

  Future<void> update(Meal meal);

  Future<Meal?> getById(int id);

  Future<List<Meal>> getByUserId(String userId);

  Future<List<Meal>> getFavorites(String userId);

  Future<void> delete(int id);
}
