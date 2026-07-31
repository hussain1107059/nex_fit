import '../entities/workout_category.dart';

/// Contract for reading the global workout category catalog.
abstract interface class WorkoutCategoryRepository {
  Future<int> insert(WorkoutCategory category);

  Future<WorkoutCategory?> getById(int id);

  Future<WorkoutCategory?> getBySlug(String slug);

  Future<List<WorkoutCategory>> getAll();
}
