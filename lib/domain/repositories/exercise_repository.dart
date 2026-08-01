import '../entities/exercise.dart';
import '../entities/exercise_filter.dart';
import '../entities/exercise_library.dart';

/// Contract for managing exercises (built-in library + user custom).
abstract interface class ExerciseRepository {
  Future<int> insert(Exercise exercise);

  Future<void> update(Exercise exercise);

  Future<Exercise?> getById(int id);

  Future<List<Exercise>> getBuiltIn();

  Future<List<Exercise>> getByUserId(String userId);

  /// Full catalog visible to [userId] (built-in + user's own).
  Future<ExerciseLibraryData> loadLibrary(String userId);

  /// Applies [filter] over the catalog for [userId].
  Future<List<Exercise>> search(ExerciseFilter filter, String userId);

  Future<List<Exercise>> getFavorites(String userId);

  Future<Set<int>> getFavoriteIds(String userId);

  /// Toggles the favourite flag of an exercise for [userId].
  Future<bool> toggleFavorite(String userId, int exerciseId);

  Future<void> delete(int id);
}
