import '../../domain/entities/meal_item.dart';
import '../../domain/repositories/meal_item_repository.dart';
import '../datasources/local/meal_item_local_data_source.dart';

/// SQLite backed implementation of [MealItemRepository].
class MealItemRepositoryImpl implements MealItemRepository {
  const MealItemRepositoryImpl(this._dataSource);

  final MealItemLocalDataSource _dataSource;

  @override
  Future<int> insert(MealItem item) => _dataSource.insert(item);

  @override
  Future<void> insertAll(List<MealItem> items) => _dataSource.insertAll(items);

  @override
  Future<void> update(MealItem item) => _dataSource.update(item);

  @override
  Future<List<MealItem>> getByMeal(int mealId) =>
      _dataSource.getByMeal(mealId);

  @override
  Future<List<MealItem>> getByMeals(List<int> mealIds) =>
      _dataSource.getByMeals(mealIds);

  @override
  Future<void> deleteByMeal(int mealId) => _dataSource.deleteByMeal(mealId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
