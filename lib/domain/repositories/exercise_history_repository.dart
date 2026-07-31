import '../entities/exercise_history.dart';

/// Contract for per-exercise details inside a workout session.
abstract interface class ExerciseHistoryRepository {
  Future<int> insert(ExerciseHistory history);

  Future<void> update(ExerciseHistory history);

  Future<ExerciseHistory?> getById(int id);

  Future<List<ExerciseHistory>> getByWorkoutHistory(int workoutHistoryId);

  Future<void> delete(int id);
}
