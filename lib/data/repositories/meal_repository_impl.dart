import '../../domain/entities/meal.dart';
import '../../domain/repositories/meal_repository.dart';
import '../datasources/local/meal_local_data_source.dart';

/// SQLite backed implementation of [MealRepository].
class MealRepositoryImpl implements MealRepository {
  const MealRepositoryImpl(this._dataSource);

  final MealLocalDataSource _dataSource;

  @override
  Future<int> insert(Meal meal) => _dataSource.insert(meal);

  @override
  Future<void> update(Meal meal) => _dataSource.update(meal);

  @override
  Future<Meal?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<Meal>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<Meal>> getFavorites(String userId) =>
      _dataSource.getFavorites(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
