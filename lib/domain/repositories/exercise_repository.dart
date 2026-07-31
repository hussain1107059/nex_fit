import '../entities/exercise.dart';

/// Contract for managing exercises (built-in library + user custom).
abstract interface class ExerciseRepository {
  Future<int> insert(Exercise exercise);

  Future<void> update(Exercise exercise);

  Future<Exercise?> getById(int id);

  Future<List<Exercise>> getBuiltIn();

  Future<List<Exercise>> getByUserId(String userId);

  Future<void> delete(int id);
}
