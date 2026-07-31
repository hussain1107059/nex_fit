import '../../domain/entities/badge.dart';
import '../../domain/entities/bmi_log.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/sleep_log.dart';
import '../../domain/entities/step_log.dart';
import '../../domain/entities/streak.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/water_log.dart';
import '../../domain/entities/weight_log.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/repositories/badge_repository.dart';
import '../../domain/repositories/bmi_log_repository.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/repositories/food_log_repository.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/repositories/sleep_log_repository.dart';
import '../../domain/repositories/step_log_repository.dart';
import '../../domain/repositories/streak_repository.dart';
import '../../domain/repositories/user_fitness_profile_repository.dart';
import '../../domain/repositories/water_log_repository.dart';
import '../../domain/repositories/weight_log_repository.dart';
import '../../domain/repositories/workout_history_repository.dart';

/// Aggregates the premium home dashboard from the user's real local records.
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({
    required this._workoutHistoryRepository,
    required this._waterLogRepository,
    required this._stepLogRepository,
    required this._weightLogRepository,
    required this._bmiLogRepository,
    required this._foodLogRepository,
    required this._sleepLogRepository,
    required this._streakRepository,
    required this._badgeRepository,
    required this._reminderRepository,
    required this._userFitnessProfileRepository,
  });

  final WorkoutHistoryRepository _workoutHistoryRepository;
  final WaterLogRepository _waterLogRepository;
  final StepLogRepository _stepLogRepository;
  final WeightLogRepository _weightLogRepository;
  final BmiLogRepository _bmiLogRepository;
  final FoodLogRepository _foodLogRepository;
  final SleepLogRepository _sleepLogRepository;
  final StreakRepository _streakRepository;
  final BadgeRepository _badgeRepository;
  final ReminderRepository _reminderRepository;
  final UserFitnessProfileRepository _userFitnessProfileRepository;

  static const int _dailyWorkoutTargetMinutes = 30;
  static const int _dailyQuoteCount = 12;

  @override
  Future<DashboardData> loadDashboard(String userId, DateTime now) async {
    final DateTime day = DateTime(now.year, now.month, now.day);
    final DateTime weekStart = day.subtract(const Duration(days: 6));

    final List<Object?> results = await Future.wait<Object?>([
      _workoutHistoryRepository.getByUserId(userId),
      _waterLogRepository.getByUserId(userId),
      _foodLogRepository.getByUserId(userId),
      _weightLogRepository.getByUserId(userId),
      _sleepLogRepository.getByUserId(userId),
      _stepLogRepository.getByUserId(userId),
      _bmiLogRepository.getByUserId(userId),
      _streakRepository.getByUserId(userId),
      _badgeRepository.getByUserId(userId),
      _reminderRepository.getEnabled(userId),
      _userFitnessProfileRepository.getById(userId),
    ]);

    final List<WorkoutHistory> workouts = results[0] as List<WorkoutHistory>;
    final List<WaterLog> waterLogs = results[1] as List<WaterLog>;
    final List<FoodLog> foodLogs = results[2] as List<FoodLog>;
    final List<WeightLog> weightLogs = results[3] as List<WeightLog>;
    final List<SleepLog> sleepLogs = results[4] as List<SleepLog>;
    final List<StepLog> stepLogs = results[5] as List<StepLog>;
    final List<BmiLog> bmiLogs = results[6] as List<BmiLog>;
    final List<Streak> streaks = results[7] as List<Streak>;
    final List<Badge> badges = results[8] as List<Badge>;
    final List<Reminder> reminders = results[9] as List<Reminder>;
    final UserProfile? profile = results[10] as UserProfile?;

    final List<WorkoutHistory> todayWorkouts = _onDay(
      workouts,
      (WorkoutHistory w) => w.startedAt,
      day,
    );
    final List<WaterLog> waterToday = _onDay(
      waterLogs,
      (WaterLog w) => w.loggedAt,
      day,
    );
    final List<FoodLog> foodToday = _onDay(
      foodLogs,
      (FoodLog f) => f.loggedAt,
      day,
    );
    final StepLog? stepToday = stepLogs
        .where((StepLog s) => _isSameDay(s.stepDate, day))
        .firstOrNull;

    final double caloriesBurnedToday =
        todayWorkouts.fold(
          0.0,
          (double sum, WorkoutHistory w) => sum + (w.caloriesBurn ?? 0),
        ) +
        (stepToday?.caloriesBurned ?? 0);
    final int waterMlToday = waterToday.fold(
      0,
      (int sum, WaterLog w) => sum + w.amountMl,
    );
    final int stepsToday = stepToday?.steps ?? 0;
    final WeightLog? latestWeight = weightLogs.firstOrNull;
    final BmiLog? latestBmi = bmiLogs.firstOrNull;
    final Streak? bestStreak = streaks.isEmpty
        ? null
        : streaks.reduce(
            (Streak a, Streak b) =>
                a.currentStreak >= b.currentStreak ? a : b,
          );
    final int workoutStreak = bestStreak?.currentStreak ?? 0;

    final DashboardSummary summary = DashboardSummary(
      caloriesBurned: caloriesBurnedToday,
      waterMl: waterMlToday,
      steps: stepsToday,
      weightKg: latestWeight?.weightKg,
      bmi: latestBmi?.bmi,
      workoutStreak: workoutStreak,
      hasWorkouts: workouts.isNotEmpty,
      hasWeight: weightLogs.isNotEmpty,
      hasActivity: workouts.isNotEmpty ||
          waterLogs.isNotEmpty ||
          foodLogs.isNotEmpty ||
          weightLogs.isNotEmpty ||
          sleepLogs.isNotEmpty,
    );

    final int workoutMinutes = todayWorkouts.fold(
      0,
      (int sum, WorkoutHistory w) => sum + (w.durationMinutes ?? 0),
    );
    final double caloriesConsumed = foodToday.fold(
      0.0,
      (double sum, FoodLog f) => sum + f.calories,
    );
    final TodayGoals goals = TodayGoals(
      workoutMinutes: workoutMinutes,
      workoutMinutesTarget: _dailyWorkoutTargetMinutes,
      caloriesConsumed: caloriesConsumed,
      calorieTarget: profile?.targetCalories,
      waterMl: waterMlToday,
      waterTargetMl: profile?.targetWaterMl,
      steps: stepsToday,
      stepTarget: profile?.targetSteps,
    );

    final List<DateTime> weekDays = <DateTime>[
      for (int i = 0; i < 7; i++) weekStart.add(Duration(days: i)),
    ];
    final List<WeeklyStatPoint> weeklyCalories = _weeklySeries(
      weekDays,
      (DateTime d) => workouts
          .where((WorkoutHistory w) => _isSameDay(w.startedAt, d))
          .fold(
            0.0,
            (double sum, WorkoutHistory w) => sum + (w.caloriesBurn ?? 0),
          ),
    );
    final List<WeeklyStatPoint> weeklyWorkout = _weeklySeries(
      weekDays,
      (DateTime d) => workouts
          .where((WorkoutHistory w) => _isSameDay(w.startedAt, d))
          .fold(
            0.0,
            (double sum, WorkoutHistory w) =>
                sum + (w.durationMinutes ?? 0),
          ),
    );
    final List<WeeklyStatPoint> weeklyWater = _weeklySeries(
      weekDays,
      (DateTime d) => waterLogs
          .where((WaterLog w) => _isSameDay(w.loggedAt, d))
          .fold(0.0, (double sum, WaterLog w) => sum + w.amountMl),
    );
    final List<WeeklyStatPoint> weeklyWeight = _weeklySeries(
      weekDays,
      (DateTime d) {
        final WeightLog? log = weightLogs
            .where((WeightLog w) => _isSameDay(w.loggedAt, d))
            .firstOrNull;
        return log?.weightKg ?? 0;
      },
    );

    final List<RecentActivityItem> recent = <RecentActivityItem>[
      if (workouts.isNotEmpty)
        RecentActivityItem(
          kind: DashboardActivityKind.workout,
          value: (workouts.first.durationMinutes ?? 0).toDouble(),
          occurredAt: workouts.first.startedAt,
        ),
      if (waterLogs.isNotEmpty)
        RecentActivityItem(
          kind: DashboardActivityKind.water,
          value: waterLogs.first.amountMl.toDouble(),
          occurredAt: waterLogs.first.loggedAt,
        ),
      if (foodLogs.isNotEmpty)
        RecentActivityItem(
          kind: DashboardActivityKind.meal,
          value: foodLogs.first.calories,
          occurredAt: foodLogs.first.loggedAt,
        ),
      if (weightLogs.isNotEmpty)
        RecentActivityItem(
          kind: DashboardActivityKind.weight,
          value: weightLogs.first.weightKg,
          occurredAt: weightLogs.first.loggedAt,
        ),
      if (sleepLogs.isNotEmpty)
        RecentActivityItem(
          kind: DashboardActivityKind.sleep,
          value: sleepLogs.first.durationMinutes.toDouble(),
          occurredAt: sleepLogs.first.sleepDate,
        ),
    ]..sort((RecentActivityItem a, RecentActivityItem b) {
        return b.occurredAt.compareTo(a.occurredAt);
      });
    final List<RecentActivityItem> recentActivity = recent.take(5).toList();

    final int weekday = now.weekday;
    final List<DashboardReminder> todayReminders = reminders
        .where(
          (Reminder r) =>
              r.daysOfWeek.isEmpty || r.daysOfWeek.contains(weekday),
        )
        .map(
          (Reminder r) => DashboardReminder(
            reminderType: r.reminderType,
            title: r.title,
            time: r.time,
          ),
        )
        .toList()
      ..sort((DashboardReminder a, DashboardReminder b) {
        return a.time.compareTo(b.time);
      });

    final List<Badge> earnedBadges = badges
        .where((Badge b) => b.isEarned)
        .toList()
      ..sort((Badge a, Badge b) {
        final DateTime? at = a.earnedAt;
        final DateTime? bt = b.earnedAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    final Badge? recentBadge = earnedBadges.firstOrNull;

    final DashboardAchievement achievement = DashboardAchievement(
      badgeName: recentBadge?.badgeName,
      badgeIcon: recentBadge?.icon,
      earnedAt: recentBadge?.earnedAt,
      currentStreak: workoutStreak,
      streakType: bestStreak?.streakType ?? StreakType.daily,
      hasBadges: badges.isNotEmpty,
    );

    return DashboardData(
      summary: summary,
      goals: goals,
      recentActivity: recentActivity,
      weeklyCalories: weeklyCalories,
      weeklyWater: weeklyWater,
      weeklyWorkout: weeklyWorkout,
      weeklyWeight: weeklyWeight,
      reminders: todayReminders,
      achievement: achievement,
      quoteIndex: dayOfYear(day) % _dailyQuoteCount,
    );
  }

  int dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays;
  }

  List<WeeklyStatPoint> _weeklySeries(
    List<DateTime> days,
    double Function(DateTime) valueOf,
  ) {
    return <WeeklyStatPoint>[
      for (final DateTime d in days) WeeklyStatPoint(date: d, value: valueOf(d)),
    ];
  }

  List<T> _onDay<T>(
    List<T> items,
    DateTime Function(T) dateOf,
    DateTime day,
  ) {
    return items.where((T item) => _isSameDay(dateOf(item), day)).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
