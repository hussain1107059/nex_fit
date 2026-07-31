import '../entities/workout.dart';
import '../entities/workout_detail.dart';
import '../entities/workout_filter.dart';
import '../entities/workout_library.dart';

/// Aggregates the offline workout library: collections, search, filters,
/// favourites and detail enrichment.
abstract interface class WorkoutLibraryRepository {
  /// Ensures the built-in exercise catalog and the default workout routines
  /// are provisioned for [userId]. Idempotent.
  Future<void> ensureSeeded(String userId);

  /// Loads every section shown on the workout home tab.
  Future<WorkoutLibraryData> loadLibrary(String userId);

  /// A single workout enriched with its category and ordered exercises.
  Future<WorkoutDetail> getDetail(int workoutId);

  /// Searches and filters the user's workouts by name, category, difficulty,
  /// muscle group, equipment, goal and duration.
  Future<List<Workout>> search(String userId, WorkoutFilter filter);

  /// All workouts belonging to a category slug.
  Future<List<Workout>> getByCategory(String userId, String categorySlug);

  /// Flips the favourite flag of a workout and returns the new state.
  Future<bool> toggleFavorite(int workoutId);
}
