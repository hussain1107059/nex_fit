import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// Activity kinds surfaced in the home dashboard "recent activity" feed.
enum DashboardActivityKind { workout, water, meal, weight, sleep }

/// Result categories for the global search.
enum GlobalSearchType { workout, exercise, food, meal }

/// Aggregated payload loaded for the premium home dashboard.
///
/// Everything here is computed from the user's real records in the local
/// database (no fake numbers).
class DashboardData extends Equatable {
  const DashboardData({
    required this.summary,
    required this.goals,
    required this.recentActivity,
    required this.weeklyCalories,
    required this.weeklyWater,
    required this.weeklyWorkout,
    required this.weeklyWeight,
    required this.reminders,
    required this.achievement,
    required this.quoteIndex,
  });

  final DashboardSummary summary;
  final TodayGoals goals;
  final List<RecentActivityItem> recentActivity;
  final List<WeeklyStatPoint> weeklyCalories;
  final List<WeeklyStatPoint> weeklyWater;
  final List<WeeklyStatPoint> weeklyWorkout;
  final List<WeeklyStatPoint> weeklyWeight;
  final List<DashboardReminder> reminders;
  final DashboardAchievement achievement;

  /// Index into the quote list so the daily quote changes every day.
  final int quoteIndex;

  @override
  List<Object?> get props => [
        summary,
        goals,
        recentActivity,
        weeklyCalories,
        weeklyWater,
        weeklyWorkout,
        weeklyWeight,
        reminders,
        achievement,
        quoteIndex,
      ];
}

/// Headline numbers shown in the gradient overview card.
class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.caloriesBurned,
    required this.waterMl,
    required this.steps,
    this.weightKg,
    this.bmi,
    required this.workoutStreak,
    required this.hasWorkouts,
    required this.hasWeight,
    required this.hasActivity,
    this.sleepMinutes = 0,
    this.hasSleep = false,
    this.totalXp = 0,
  });

  final double caloriesBurned;
  final int waterMl;
  final int steps;
  final double? weightKg;
  final double? bmi;
  final int workoutStreak;
  final bool hasWorkouts;
  final bool hasWeight;
  final bool hasActivity;

  /// Minutes slept on the most recent logged night.
  final int sleepMinutes;
  final bool hasSleep;

  /// Lifetime experience points from the `user_level` singleton.
  final int totalXp;

  @override
  List<Object?> get props => [
        caloriesBurned,
        waterMl,
        steps,
        weightKg,
        bmi,
        workoutStreak,
        hasWorkouts,
        hasWeight,
        hasActivity,
        sleepMinutes,
        hasSleep,
        totalXp,
      ];
}

/// Today's progress toward the four goal rings.
class TodayGoals extends Equatable {
  const TodayGoals({
    required this.workoutMinutes,
    required this.workoutMinutesTarget,
    required this.caloriesConsumed,
    this.calorieTarget,
    required this.waterMl,
    this.waterTargetMl,
    required this.steps,
    this.stepTarget,
  });

  final int workoutMinutes;
  final int workoutMinutesTarget;
  final double caloriesConsumed;
  final double? calorieTarget;
  final int waterMl;
  final int? waterTargetMl;
  final int steps;
  final int? stepTarget;

  @override
  List<Object?> get props => [
        workoutMinutes,
        workoutMinutesTarget,
        caloriesConsumed,
        calorieTarget,
        waterMl,
        waterTargetMl,
        steps,
        stepTarget,
      ];
}

/// One entry in the "recent activity" feed.
class RecentActivityItem extends Equatable {
  const RecentActivityItem({
    required this.kind,
    this.value,
    required this.occurredAt,
  });

  final DashboardActivityKind kind;
  final double? value;
  final DateTime occurredAt;

  @override
  List<Object?> get props => [kind, value, occurredAt];
}

/// A single day inside a weekly chart series.
class WeeklyStatPoint extends Equatable {
  const WeeklyStatPoint({required this.date, required this.value});

  final DateTime date;
  final double value;

  @override
  List<Object?> get props => [date, value];
}

/// A reminder scheduled for today.
class DashboardReminder extends Equatable {
  const DashboardReminder({
    required this.reminderType,
    required this.title,
    required this.time,
  });

  final ReminderType reminderType;
  final String title;

  /// 24h "HH:mm" time string.
  final String time;

  @override
  List<Object?> get props => [reminderType, title, time];
}

/// Latest badge and current streak shown in the achievements card.
class DashboardAchievement extends Equatable {
  const DashboardAchievement({
    this.badgeName,
    this.badgeIcon,
    this.earnedAt,
    required this.currentStreak,
    required this.streakType,
    required this.hasBadges,
  });

  final String? badgeName;
  final String? badgeIcon;
  final DateTime? earnedAt;
  final int currentStreak;
  final StreakType streakType;
  final bool hasBadges;

  @override
  List<Object?> get props => [
        badgeName,
        badgeIcon,
        earnedAt,
        currentStreak,
        streakType,
        hasBadges,
      ];
}

/// A single match from the global search.
class GlobalSearchResult extends Equatable {
  const GlobalSearchResult({
    required this.type,
    this.id,
    required this.title,
    this.subtitle,
  });

  final GlobalSearchType type;
  final int? id;
  final String title;
  final String? subtitle;

  @override
  List<Object?> get props => [type, id, title, subtitle];
}
