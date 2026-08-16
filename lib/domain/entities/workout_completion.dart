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
    this.xpEarned = 0,
    this.xpTotal = 0,
    this.level = 1,
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

  /// XP awarded for completing this session (0 if already awarded).
  final int xpEarned;

  /// Running XP total for the user after this session.
  final int xpTotal;

  /// User level after applying this session's XP.
  final int level;

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
        xpEarned,
        xpTotal,
        level,
      ];
}
