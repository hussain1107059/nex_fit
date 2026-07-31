import '../../domain/entities/exercise_history.dart';
import '../../domain/repositories/exercise_history_repository.dart';
import '../datasources/local/exercise_history_local_data_source.dart';

/// SQLite backed implementation of [ExerciseHistoryRepository].
class ExerciseHistoryRepositoryImpl implements ExerciseHistoryRepository {
  const ExerciseHistoryRepositoryImpl(this._dataSource);

  final ExerciseHistoryLocalDataSource _dataSource;

  @override
  Future<int> insert(ExerciseHistory history) => _dataSource.insert(history);

  @override
  Future<void> update(ExerciseHistory history) => _dataSource.update(history);

  @override
  Future<ExerciseHistory?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<ExerciseHistory>> getByWorkoutHistory(int workoutHistoryId) =>
      _dataSource.getByWorkoutHistory(workoutHistoryId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
