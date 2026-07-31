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
  Future<void> delete(int id) => _dataSource.delete(id);
}
