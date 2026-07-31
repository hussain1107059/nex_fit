import '../entities/exercise_history.dart';
import '../entities/workout_completion.dart';

/// Manages the lifecycle of a workout session: starting a session, and
/// completing it (history, per-exercise log, daily progress, streak and
/// achievements).
abstract interface class WorkoutSessionRepository {
  /// Opens a new session for [workoutId] and returns its history row id.
  Future<int> startSession({
    required String userId,
    required int workoutId,
  });

  /// Marks a session as completed and persists every side-effect.
  Future<WorkoutCompletion> completeSession({
    required int historyId,
    required int durationMinutes,
    required double caloriesBurned,
    required List<ExerciseHistory> exerciseHistories,
  });
}
