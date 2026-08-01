import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_filter.dart';
import '../../domain/entities/exercise_library.dart';
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
  Future<ExerciseLibraryData> loadLibrary(String userId) async {
    final List<Exercise> all = await _dataSource.getAll(userId);
    final List<Exercise> favorites = await _dataSource.getFavorites(userId);
    return ExerciseLibraryData(
      exercises: all,
      favorites: favorites,
    );
  }

  @override
  Future<List<Exercise>> search(ExerciseFilter filter, String userId) =>
      _dataSource.search(filter, userId);

  @override
  Future<List<Exercise>> getFavorites(String userId) =>
      _dataSource.getFavorites(userId);

  @override
  Future<Set<int>> getFavoriteIds(String userId) =>
      _dataSource.getFavoriteIds(userId);

  @override
  Future<bool> toggleFavorite(String userId, int exerciseId) async {
    final Set<int> ids = await _dataSource.getFavoriteIds(userId);
    final bool isFavorite = ids.contains(exerciseId);
    if (isFavorite) {
      await _dataSource.removeFavorite(userId, exerciseId);
    } else {
      await _dataSource.addFavorite(userId, exerciseId);
    }
    return !isFavorite;
  }

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
