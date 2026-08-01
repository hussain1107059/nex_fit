import '../entities/food_filter.dart';
import '../entities/food_item.dart';

/// Contract for managing foods (built-in database + user custom).
abstract interface class FoodItemRepository {
  Future<int> insert(FoodItem item);

  Future<void> update(FoodItem item);

  Future<FoodItem?> getById(int id);

  Future<List<FoodItem>> getBuiltIn();

  Future<List<FoodItem>> getByUserId(String userId);

  /// Full catalog for [userId] (built-in + custom) with favourite flags.
  Future<List<FoodItem>> getCatalog(String userId);

  /// Searches the catalog with [filter], annotating favourite flags.
  Future<List<FoodItem>> search(FoodFilter filter, String userId);

  Future<List<FoodItem>> getFavorites(String userId);

  Future<Set<int>> getFavoriteIds(String userId);

  Future<bool> toggleFavorite(String userId, int foodItemId);

  Future<void> delete(int id);
}
