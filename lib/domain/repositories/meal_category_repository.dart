import '../entities/meal_category.dart';

/// Contract for reading the global meal category catalog.
abstract interface class MealCategoryRepository {
  Future<int> insert(MealCategory category);

  Future<MealCategory?> getById(int id);

  Future<MealCategory?> getBySlug(String slug);

  Future<List<MealCategory>> getAll();
}
