import '../entities/food_item.dart';

/// Contract for managing foods (built-in database + user custom).
abstract interface class FoodItemRepository {
  Future<int> insert(FoodItem item);

  Future<void> update(FoodItem item);

  Future<FoodItem?> getById(int id);

  Future<List<FoodItem>> getBuiltIn();

  Future<List<FoodItem>> getByUserId(String userId);

  Future<void> delete(int id);
}
