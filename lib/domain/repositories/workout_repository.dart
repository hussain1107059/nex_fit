import '../entities/workout.dart';

/// Contract for managing a user's workout routines.
abstract interface class WorkoutRepository {
  Future<int> insert(Workout workout);

  Future<void> update(Workout workout);

  Future<Workout?> getById(int id);

  Future<List<Workout>> getByIds(List<int> ids);

  Future<List<Workout>> getByUserId(String userId);

  Future<List<Workout>> getByCategory(int categoryId);

  Future<List<Workout>> getByCategoryForUser(String userId, int categoryId);

  Future<List<Workout>> getFavorites(String userId);

  Future<void> setFavorite(int id, bool favorite);

  Future<void> delete(int id);
}
