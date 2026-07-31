import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/local/workout_local_data_source.dart';

/// SQLite backed implementation of [WorkoutRepository].
class WorkoutRepositoryImpl implements WorkoutRepository {
  const WorkoutRepositoryImpl(this._dataSource);

  final WorkoutLocalDataSource _dataSource;

  @override
  Future<int> insert(Workout workout) => _dataSource.insert(workout);

  @override
  Future<void> update(Workout workout) => _dataSource.update(workout);

  @override
  Future<Workout?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<Workout>> getByIds(List<int> ids) => _dataSource.getByIds(ids);

  @override
  Future<List<Workout>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<Workout>> getByCategory(int categoryId) =>
      _dataSource.getByCategory(categoryId);

  @override
  Future<List<Workout>> getByCategoryForUser(String userId, int categoryId) =>
      _dataSource.getByCategoryForUser(userId, categoryId);

  @override
  Future<List<Workout>> getFavorites(String userId) =>
      _dataSource.getFavorites(userId);

  @override
  Future<void> setFavorite(int id, bool favorite) =>
      _dataSource.setFavorite(id, favorite);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
