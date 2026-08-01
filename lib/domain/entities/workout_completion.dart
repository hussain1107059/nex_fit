import 'package:equatable/equatable.dart';

import 'achievement.dart';
import 'badge.dart';

/// Result captured when a workout session is finished.
class WorkoutCompletion extends Equatable {
  const WorkoutCompletion({
    required this.historyId,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.exercisesCompleted,
    required this.totalExercises,
    required this.completedAt,
    this.workoutName,
    this.completionPercent = 0,
    this.currentStreak = 0,
    this.newAchievements = const <Achievement>[],
    this.newBadges = const <Badge>[],
  });

  final int historyId;
  final int durationMinutes;
  final double caloriesBurned;
  final int exercisesCompleted;
  final int totalExercises;
  final DateTime completedAt;

  /// Name of the routine that was completed, if known.
  final String? workoutName;

  /// Percentage of the routine finished (0-100).
  final double completionPercent;

  /// Current workout streak after this session.
  final int currentStreak;

  /// Achievements unlocked by this session.
  final List<Achievement> newAchievements;

  /// Badges earned by this session.
  final List<Badge> newBadges;

  double get completionRatio =>
      totalExercises == 0 ? 0 : exercisesCompleted / totalExercises;

  @override
  List<Object?> get props => [
        historyId,
        durationMinutes,
        caloriesBurned,
        exercisesCompleted,
        totalExercises,
        completedAt,
        workoutName,
        completionPercent,
        currentStreak,
        newAchievements,
        newBadges,
      ];
}
