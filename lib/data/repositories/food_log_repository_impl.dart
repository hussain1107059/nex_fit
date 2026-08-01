import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/repositories/food_log_repository.dart';
import '../datasources/local/food_log_local_data_source.dart';

/// SQLite backed implementation of [FoodLogRepository].
class FoodLogRepositoryImpl implements FoodLogRepository {
  const FoodLogRepositoryImpl(this._dataSource);

  final FoodLogLocalDataSource _dataSource;

  @override
  Future<int> insert(FoodLog log) => _dataSource.insert(log);

  @override
  Future<void> insertAll(List<FoodLog> logs) => _dataSource.insertAll(logs);

  @override
  Future<void> update(FoodLog log) => _dataSource.update(log);

  @override
  Future<FoodLog?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<FoodLog>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<FoodLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) => _dataSource.getByDateRange(userId, start, end);

  @override
  Future<List<FoodItem>> getRecentFoods(String userId, {int limit = 12}) =>
      _dataSource.getRecentFoods(userId, limit: limit);

  @override
  Future<List<FoodItem>> getFrequentFoods(String userId, {int limit = 12}) =>
      _dataSource.getFrequentFoods(userId, limit: limit);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
