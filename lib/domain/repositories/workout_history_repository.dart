import '../entities/workout_history.dart';

/// Contract for the user's workout session history.
abstract interface class WorkoutHistoryRepository {
  Future<int> insert(WorkoutHistory history);

  Future<void> update(WorkoutHistory history);

  Future<WorkoutHistory?> getById(int id);

  Future<List<WorkoutHistory>> getByUserId(String userId);

  Future<List<WorkoutHistory>> getCompleted(String userId);

  Future<WorkoutHistory?> getInProgress(String userId);

  Future<List<int>> getRecentWorkoutIds(String userId, {int limit = 10});

  Future<List<int>> getPopularWorkoutIds(String userId, {int limit = 10});

  Future<int> countCompleted(String userId);

  Future<double> getTotalCaloriesBurned(String userId);

  Future<List<WorkoutHistory>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  Future<void> delete(int id);
}
