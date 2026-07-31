import '../../domain/entities/exercise.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../datasources/local/exercise_local_data_source.dart';

/// SQLite backed implementation of [ExerciseRepository].
class ExerciseRepositoryImpl implements ExerciseRepository {
  const ExerciseRepositoryImpl(this._dataSource);

  final ExerciseLocalDataSource _dataSource;

  @override
  Future<int> insert(Exercise exercise) => _dataSource.insert(exercise);

  @override
  Future<void> update(Exercise exercise) => _dataSource.update(exercise);

  @override
  Future<Exercise?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<Exercise>> getBuiltIn() => _dataSource.getBuiltIn();

  @override
  Future<List<Exercise>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
