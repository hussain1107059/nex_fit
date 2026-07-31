import '../../domain/entities/workout_history.dart';
import '../../domain/repositories/workout_history_repository.dart';
import '../datasources/local/workout_history_local_data_source.dart';

/// SQLite backed implementation of [WorkoutHistoryRepository].
class WorkoutHistoryRepositoryImpl implements WorkoutHistoryRepository {
  const WorkoutHistoryRepositoryImpl(this._dataSource);

  final WorkoutHistoryLocalDataSource _dataSource;

  @override
  Future<int> insert(WorkoutHistory history) => _dataSource.insert(history);

  @override
  Future<void> update(WorkoutHistory history) => _dataSource.update(history);

  @override
  Future<WorkoutHistory?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<WorkoutHistory>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<WorkoutHistory>> getCompleted(String userId) =>
      _dataSource.getCompleted(userId);

  @override
  Future<WorkoutHistory?> getInProgress(String userId) =>
      _dataSource.getInProgress(userId);

  @override
  Future<List<int>> getRecentWorkoutIds(String userId, {int limit = 10}) =>
      _dataSource.getRecentWorkoutIds(userId, limit: limit);

  @override
  Future<List<int>> getPopularWorkoutIds(String userId, {int limit = 10}) =>
      _dataSource.getPopularWorkoutIds(userId, limit: limit);

  @override
  Future<int> countCompleted(String userId) =>
      _dataSource.countCompleted(userId);

  @override
  Future<double> getTotalCaloriesBurned(String userId) =>
      _dataSource.getTotalCaloriesBurned(userId);

  @override
  Future<List<WorkoutHistory>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) => _dataSource.getByDateRange(userId, start, end);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
