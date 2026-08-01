import '../../domain/entities/food_filter.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/repositories/food_item_repository.dart';
import '../datasources/local/food_item_local_data_source.dart';

/// SQLite backed implementation of [FoodItemRepository].
class FoodItemRepositoryImpl implements FoodItemRepository {
  const FoodItemRepositoryImpl(this._dataSource);

  final FoodItemLocalDataSource _dataSource;

  @override
  Future<int> insert(FoodItem item) => _dataSource.insert(item);

  @override
  Future<void> update(FoodItem item) => _dataSource.update(item);

  @override
  Future<FoodItem?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<FoodItem>> getBuiltIn() => _dataSource.getBuiltIn();

  @override
  Future<List<FoodItem>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<FoodItem>> getCatalog(String userId) =>
      _dataSource.getCatalog(userId);

  @override
  Future<List<FoodItem>> search(FoodFilter filter, String userId) =>
      _dataSource.search(filter, userId);

  @override
  Future<List<FoodItem>> getFavorites(String userId) =>
      _dataSource.getFavorites(userId);

  @override
  Future<Set<int>> getFavoriteIds(String userId) =>
      _dataSource.getFavoriteIds(userId);

  @override
  Future<bool> toggleFavorite(String userId, int foodItemId) async {
    final Set<int> ids = await _dataSource.getFavoriteIds(userId);
    final bool isFavorite = ids.contains(foodItemId);
    if (isFavorite) {
      await _dataSource.removeFavorite(userId, foodItemId);
    } else {
      await _dataSource.addFavorite(userId, foodItemId);
    }
    return !isFavorite;
  }

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
