import '../../core/utils/date_helpers.dart';
import '../../domain/entities/bmi_log.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/entities/fitness_goal.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/progress/analytics_report.dart';
import '../../domain/entities/progress/analytics_summary.dart';
import '../../domain/entities/progress/fitness_score.dart';
import '../../domain/entities/progress/goal_progress.dart';
import '../../domain/entities/progress/personal_record.dart';
import '../../domain/entities/progress/report_period.dart';
import '../../domain/entities/sleep_log.dart';
import '../../domain/entities/step_log.dart';
import '../../domain/entities/streak.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/water_log.dart';
import '../../domain/entities/weight_log.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/repositories/bmi_log_repository.dart';
import '../../domain/repositories/fitness_goal_repository.dart';
import '../../domain/repositories/food_log_repository.dart';
import '../../domain/repositories/progress_analytics_repository.dart';
import '../../domain/repositories/sleep_log_repository.dart';
import '../../domain/repositories/step_log_repository.dart';
import '../../domain/repositories/streak_repository.dart';
import '../../domain/repositories/user_fitness_profile_repository.dart';
import '../../domain/repositories/water_log_repository.dart';
import '../../domain/repositories/weight_log_repository.dart';
import '../../domain/repositories/workout_history_repository.dart';

/// Aggregates the Progress & Analytics module from the user's real local
/// records across every tracking module (workouts, hydration, nutrition,
/// weight, sleep, steps).
class ProgressAnalyticsRepositoryImpl implements ProgressAnalyticsRepository {
  ProgressAnalyticsRepositoryImpl({
    required this._workoutHistoryRepository,
    required this._waterLogRepository,
    required this._foodLogRepository,
    required this._weightLogRepository,
    required this._bmiLogRepository,
    required this._sleepLogRepository,
    required this._stepLogRepository,
    required this._streakRepository,
    required this._fitnessGoalRepository,
    required this._userFitnessProfileRepository,
  });

  final WorkoutHistoryRepository _workoutHistoryRepository;
  final WaterLogRepository _waterLogRepository;
  final FoodLogRepository _foodLogRepository;
  final WeightLogRepository _weightLogRepository;
  final BmiLogRepository _bmiLogRepository;
  final SleepLogRepository _sleepLogRepository;
  final StepLogRepository _stepLogRepository;
  final StreakRepository _streakRepository;
  final FitnessGoalRepository _fitnessGoalRepository;
  final UserFitnessProfileRepository _userFitnessProfileRepository;

  static const int _defaultWeeklyWorkoutTarget = 4;
  static const int _defaultSleepTargetHours = 8;
  static const int _defaultStepsTarget = 8000;
  static const int _defaultWaterTargetMl = 2500;
  static const int _monthlyWorkoutTarget = 12;

  @override
  Future<AnalyticsReport> loadReport(
    String userId,
    ReportPeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final DateTime now = DateTime.now();
    final (DateTime start, DateTime end, AnalyticsGranularity granularity) =
        _windowFor(period, now, customStart, customEnd);

    final List<Object?> results = await Future.wait<Object?>([
      _workoutHistoryRepository.getByDateRange(userId, start, end),
      _waterLogRepository.getByDateRange(userId, start, end),
      _foodLogRepository.getByDateRange(userId, start, end),
      _weightLogRepository.getByDateRange(userId, start, end),
      _bmiLogRepository.getByUserId(userId),
      _sleepLogRepository.getByUserId(userId),
      _stepLogRepository.getByUserId(userId),
    ]);

    final List<WorkoutHistory> workouts = results[0] as List<WorkoutHistory>;
    final List<WaterLog> waterLogs = results[1] as List<WaterLog>;
    final List<FoodLog> foodLogs = results[2] as List<FoodLog>;
    final List<WeightLog> weightLogs = results[3] as List<WeightLog>;
    final List<BmiLog> bmiLogs = (results[4] as List<BmiLog>)
        .where((BmiLog b) => _inRange(b.loggedAt, start, end))
        .toList();
    final List<SleepLog> sleepLogs = (results[5] as List<SleepLog>)
        .where((SleepLog s) => _inRange(s.sleepDate, start, end))
        .toList();
    final List<StepLog> stepLogs = (results[6] as List<StepLog>)
        .where((StepLog s) => _inRange(s.stepDate, start, end))
        .toList();

    final List<WorkoutHistory> completed = workouts
        .where((WorkoutHistory w) => w.isCompleted)
        .toList();

    final List<DateTime> bucketDays = _bucketDays(start, end, granularity);
    double? carriedWeight;
    double? carriedBmi;
    final List<AnalyticsDataPoint> series = <AnalyticsDataPoint>[];
    for (final DateTime bucketStart in bucketDays) {
      final DateTime bucketEnd = _bucketEnd(bucketStart, granularity, end);
      final AnalyticsDataPoint point = _pointFor(
        bucketStart: bucketStart,
        bucketEnd: bucketEnd,
        granularity: granularity,
        bucketIndex: series.length,
        workouts: completed,
        waterLogs: waterLogs,
        foodLogs: foodLogs,
        stepLogs: stepLogs,
        sleepLogs: sleepLogs,
        weightLogs: weightLogs,
        bmiLogs: bmiLogs,
        carriedWeight: carriedWeight,
        carriedBmi: carriedBmi,
      );
      carriedWeight = point.weightKg ?? carriedWeight;
      carriedBmi = point.bmi ?? carriedBmi;
      series.add(point);
    }

    final AnalyticsSummary summary = _summaryFor(
      workouts: completed,
      waterLogs: waterLogs,
      foodLogs: foodLogs,
      stepLogs: stepLogs,
      sleepLogs: sleepLogs,
      weightLogs: weightLogs,
      bmiLogs: bmiLogs,
    );

    final bool hasAnyData =
        completed.isNotEmpty ||
        waterLogs.isNotEmpty ||
        foodLogs.isNotEmpty ||
        weightLogs.isNotEmpty ||
        sleepLogs.isNotEmpty ||
        stepLogs.isNotEmpty ||
        bmiLogs.isNotEmpty;

    return AnalyticsReport(
      period: period,
      start: start,
      end: end.subtract(const Duration(milliseconds: 1)),
      summary: summary,
      series: series,
      hasAnyData: hasAnyData,
    );
  }

  @override
  Future<List<PersonalRecord>> loadPersonalRecords(String userId) async {
    final List<Object?> results = await Future.wait<Object?>([
      _workoutHistoryRepository.getCompleted(userId),
      _stepLogRepository.getByUserId(userId),
      _streakRepository.getByUserId(userId),
    ]);

    final List<WorkoutHistory> workouts = results[0] as List<WorkoutHistory>;
    final List<StepLog> stepLogs = results[1] as List<StepLog>;
    final List<Streak> streaks = results[2] as List<Streak>;

    final List<PersonalRecord> records = <PersonalRecord>[];

    final WorkoutHistory? longest = _maxBy(
      workouts,
      (WorkoutHistory w) => (w.durationMinutes ?? 0).toDouble(),
    );
    if (longest != null && (longest.durationMinutes ?? 0) > 0) {
      records.add(
        PersonalRecord(
          kind: RecordKind.longestWorkout,
          value: longest.durationMinutes!.toDouble(),
          unit: 'min',
          occurredOn: longest.startedAt,
        ),
      );
    }

    final WorkoutHistory? hottest = _maxBy(
      workouts,
      (WorkoutHistory w) => w.caloriesBurn ?? 0,
    );
    if (hottest != null && (hottest.caloriesBurn ?? 0) > 0) {
      records.add(
        PersonalRecord(
          kind: RecordKind.highestCalories,
          value: hottest.caloriesBurn,
          unit: 'kcal',
          occurredOn: hottest.startedAt,
        ),
      );
    }

    final WorkoutHistory? fastest = _minBy(
      workouts.where(
        (WorkoutHistory w) => (w.durationMinutes ?? 0) > 0,
      ),
      (WorkoutHistory w) => w.durationMinutes!.toDouble(),
    );
    if (fastest != null) {
      records.add(
        PersonalRecord(
          kind: RecordKind.fastestWorkout,
          value: fastest.durationMinutes!.toDouble(),
          unit: 'min',
          occurredOn: fastest.startedAt,
        ),
      );
    }

    final Streak? bestStreak = _maxBy(
      streaks,
      (Streak s) => s.longestStreak.toDouble(),
    );
    if (bestStreak != null && bestStreak.longestStreak > 0) {
      records.add(
        PersonalRecord(
          kind: RecordKind.longestStreak,
          value: bestStreak.longestStreak.toDouble(),
          unit: 'days',
          occurredOn: bestStreak.bestDate ?? bestStreak.lastActiveDate,
        ),
      );
    }

    final Map<DateTime, double> dailyCalories = <DateTime, double>{};
    for (final WorkoutHistory w in workouts) {
      final DateTime day = DateTime(
        w.startedAt.year,
        w.startedAt.month,
        w.startedAt.day,
      );
      dailyCalories.update(
        day,
        (double value) => value + (w.caloriesBurn ?? 0),
        ifAbsent: () => w.caloriesBurn ?? 0,
      );
    }
    for (final StepLog s in stepLogs) {
      final DateTime day = DateTime(
        s.stepDate.year,
        s.stepDate.month,
        s.stepDate.day,
      );
      dailyCalories.update(
        day,
        (double value) => value + s.caloriesBurned,
        ifAbsent: () => s.caloriesBurned,
      );
    }

    if (dailyCalories.isNotEmpty) {
      final MapEntry<DateTime, double> active =
          dailyCalories.entries.reduce(
            (MapEntry<DateTime, double> a, MapEntry<DateTime, double> b) =>
                a.value >= b.value ? a : b,
          );
      records.add(
        PersonalRecord(
          kind: RecordKind.mostActiveDay,
          value: active.value,
          unit: 'kcal',
          activeDay: active.key,
        ),
      );
    }

    final Map<DateTime, double> weekCalories = <DateTime, double>{};
    final Map<DateTime, double> monthCalories = <DateTime, double>{};
    for (final WorkoutHistory w in workouts) {
      final double calories = w.caloriesBurn ?? 0;
      final DateTime week = weekStart(w.startedAt);
      weekCalories.update(
        week,
        (double value) => value + calories,
        ifAbsent: () => calories,
      );
      final DateTime month = DateTime(w.startedAt.year, w.startedAt.month, 1);
      monthCalories.update(
        month,
        (double value) => value + calories,
        ifAbsent: () => calories,
      );
    }
    if (weekCalories.isNotEmpty) {
      final MapEntry<DateTime, double> best =
          weekCalories.entries.reduce(
            (MapEntry<DateTime, double> a, MapEntry<DateTime, double> b) =>
                a.value >= b.value ? a : b,
          );
      records.add(
        PersonalRecord(
          kind: RecordKind.bestWeek,
          value: best.value,
          unit: 'kcal',
          weekStart: best.key,
        ),
      );
    }
    if (monthCalories.isNotEmpty) {
      final MapEntry<DateTime, double> best =
          monthCalories.entries.reduce(
            (MapEntry<DateTime, double> a, MapEntry<DateTime, double> b) =>
                a.value >= b.value ? a : b,
          );
      records.add(
        PersonalRecord(
          kind: RecordKind.bestMonth,
          value: best.value,
          unit: 'kcal',
          monthStart: best.key,
        ),
      );
    }

    return records;
  }

  @override
  Future<List<GoalProgress>> loadGoalProgress(String userId) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime weekStart = today.subtract(const Duration(days: 6));
    final DateTime weekEnd = today.add(const Duration(days: 1));

    final List<Object?> results = await Future.wait<Object?>([
      _workoutHistoryRepository.getByDateRange(userId, weekStart, weekEnd),
      _waterLogRepository.getByDateRange(userId, weekStart, weekEnd),
      _foodLogRepository.getByDateRange(userId, weekStart, weekEnd),
      _weightLogRepository.getByUserId(userId),
      _stepLogRepository.getByUserId(userId),
      _sleepLogRepository.getByUserId(userId),
      _fitnessGoalRepository.getByUserId(userId),
      _userFitnessProfileRepository.getById(userId),
      _streakRepository.getByUserId(userId),
    ]);

    final List<WorkoutHistory> workouts = results[0] as List<WorkoutHistory>;
    final List<WaterLog> waterLogs = results[1] as List<WaterLog>;
    final List<FoodLog> foodLogs = results[2] as List<FoodLog>;
    final List<WeightLog> weightLogs = (results[3] as List<WeightLog>)
      ..sort((WeightLog a, WeightLog b) => a.loggedAt.compareTo(b.loggedAt));
    final List<StepLog> stepLogs = results[4] as List<StepLog>;
    final List<SleepLog> sleepLogs = results[5] as List<SleepLog>;
    final List<FitnessGoal> goals = results[6] as List<FitnessGoal>;
    final UserProfile? profile = results[7] as UserProfile?;
    final List<Streak> streaks = results[8] as List<Streak>;

    final List<WorkoutHistory> completed = workouts
        .where((WorkoutHistory w) => w.isCompleted)
        .toList();
    final int weekWorkouts = completed.length;
    final double weekCaloriesConsumed = foodLogs.fold(
      0.0,
      (double sum, FoodLog f) => sum + f.calories,
    );
    final int foodDays = foodLogs
        .map((FoodLog f) => DateTime(
              f.loggedAt.year,
              f.loggedAt.month,
              f.loggedAt.day,
            ))
        .toSet()
        .length;
    final int weekWaterMl = waterLogs.fold(
      0,
      (int sum, WaterLog w) => sum + w.amountMl,
    );
    final int waterDays = waterLogs
        .map((WaterLog w) => DateTime(
              w.loggedAt.year,
              w.loggedAt.month,
              w.loggedAt.day,
            ))
        .toSet()
        .length;
    final int weekSteps = stepLogs
        .where((StepLog s) => _inRange(s.stepDate, weekStart, weekEnd))
        .fold(0, (int sum, StepLog s) => sum + s.steps);
    final int stepDays = stepLogs
        .where((StepLog s) => _inRange(s.stepDate, weekStart, weekEnd))
        .map((StepLog s) => DateTime(
              s.stepDate.year,
              s.stepDate.month,
              s.stepDate.day,
            ))
        .toSet()
        .length;
    final int weekSleepMinutes = sleepLogs
        .where((SleepLog s) => _inRange(s.sleepDate, weekStart, weekEnd))
        .fold(0, (int sum, SleepLog s) => sum + s.durationMinutes);
    final int sleepDays = sleepLogs
        .where((SleepLog s) => _inRange(s.sleepDate, weekStart, weekEnd))
        .map((SleepLog s) => DateTime(
              s.sleepDate.year,
              s.sleepDate.month,
              s.sleepDate.day,
            ))
        .toSet()
        .length;

    final List<GoalProgress> result = <GoalProgress>[];

    final int workoutStreak = _streakFor(
      streaks,
      StreakType.workout,
    );
    final int waterStreak = _streakFor(streaks, StreakType.water);
    final int stepStreak = _streakFor(streaks, StreakType.step);
    final int sleepStreak = _streakFor(streaks, StreakType.sleep);

    final double? startWeight =
        weightLogs.isEmpty ? null : weightLogs.first.weightKg;
    final double? currentWeight =
        weightLogs.isEmpty ? null : weightLogs.last.weightKg;
    final double? targetWeight =
        profile?.targetWeightKg ?? _explicitWeightTarget(goals);
    result.add(
      GoalProgress(
        kind: GoalKind.weight,
        title: 'weight',
        current: currentWeight ?? startWeight ?? 0,
        target: targetWeight ?? 0,
        unit: 'kg',
        start: startWeight,
        hasTarget: targetWeight != null && startWeight != null,
        targetDate: _explicitWeightTargetDate(goals),
        streak: currentStreak(
          weightLogs
              .map((WeightLog w) => dayStart(w.loggedAt))
              .toSet(),
          now,
        ),
      ),
    );

    final double workoutTarget = _explicitWorkoutTarget(goals) ??
        _defaultWeeklyWorkoutTarget.toDouble();
    result.add(
      GoalProgress(
        kind: GoalKind.workout,
        title: 'workout',
        current: weekWorkouts.toDouble(),
        target: workoutTarget,
        unit: 'workouts',
        hasTarget: true,
        streak: workoutStreak,
      ),
    );

    final double? calorieTarget = profile?.targetCalories;
    final double avgConsumed = foodDays == 0
        ? 0
        : weekCaloriesConsumed / foodDays;
    result.add(
      GoalProgress(
        kind: GoalKind.calories,
        title: 'calories',
        current: avgConsumed,
        target: calorieTarget ?? 0,
        unit: 'kcal',
        hasTarget: calorieTarget != null && calorieTarget > 0,
      ),
    );

    final int? waterTarget = profile?.targetWaterMl;
    final double avgWater =
        waterDays == 0 ? 0 : weekWaterMl / waterDays;
    result.add(
      GoalProgress(
        kind: GoalKind.water,
        title: 'water',
        current: avgWater,
        target: (waterTarget ?? 0).toDouble(),
        unit: 'ml',
        hasTarget: waterTarget != null && waterTarget > 0,
        streak: waterStreak,
      ),
    );

    final int? stepsTarget = profile?.targetSteps;
    final double avgSteps = stepDays == 0 ? 0 : weekSteps / stepDays;
    result.add(
      GoalProgress(
        kind: GoalKind.steps,
        title: 'steps',
        current: avgSteps,
        target: (stepsTarget ?? 0).toDouble(),
        unit: 'steps',
        hasTarget: stepsTarget != null && stepsTarget > 0,
        streak: stepStreak,
      ),
    );

    final double avgSleepHours =
        sleepDays == 0 ? 0 : weekSleepMinutes / 60 / sleepDays;
    result.add(
      GoalProgress(
        kind: GoalKind.sleep,
        title: 'sleep',
        current: avgSleepHours,
        target: _defaultSleepTargetHours.toDouble(),
        unit: 'hrs',
        hasTarget: true,
        streak: sleepStreak,
      ),
    );

    return result;
  }

  @override
  Future<FitnessScore> loadFitnessScore(String userId) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime weekStart = today.subtract(const Duration(days: 6));
    final DateTime monthStart = today.subtract(const Duration(days: 29));
    final DateTime tomorrow = today.add(const Duration(days: 1));

    final List<Object?> results = await Future.wait<Object?>([
      _workoutHistoryRepository.getByDateRange(userId, monthStart, tomorrow),
      _workoutHistoryRepository.getByDateRange(userId, weekStart, tomorrow),
      _stepLogRepository.getByUserId(userId),
      _waterLogRepository.getByDateRange(userId, weekStart, tomorrow),
      _sleepLogRepository.getByUserId(userId),
      _foodLogRepository.getByDateRange(userId, weekStart, tomorrow),
      _streakRepository.getByUserId(userId),
      _userFitnessProfileRepository.getById(userId),
    ]);

    final List<WorkoutHistory> monthWorkouts = results[0] as List<WorkoutHistory>;
    final List<StepLog> stepLogs = results[2] as List<StepLog>;
    final List<WaterLog> waterLogs = results[3] as List<WaterLog>;
    final List<SleepLog> sleepLogs = results[4] as List<SleepLog>;
    final List<FoodLog> foodLogs = results[5] as List<FoodLog>;
    final List<Streak> streaks = results[6] as List<Streak>;
    final UserProfile? profile = results[7] as UserProfile?;

    final int monthCount = monthWorkouts
        .where((WorkoutHistory w) => w.isCompleted)
        .length;
    final List<StepLog> weekSteps = stepLogs
        .where((StepLog s) => _inRange(s.stepDate, weekStart, tomorrow))
        .toList();
    final List<SleepLog> weekSleep = sleepLogs
        .where((SleepLog s) => _inRange(s.sleepDate, weekStart, tomorrow))
        .toList();

    final int weekStepsTotal = weekSteps.fold(
      0,
      (int sum, StepLog s) => sum + s.steps,
    );
    final int weekWaterMl = waterLogs.fold(
      0,
      (int sum, WaterLog w) => sum + w.amountMl,
    );
    final int weekSleepMinutes = weekSleep.fold(
      0,
      (int sum, SleepLog s) => sum + s.durationMinutes,
    );
    final double weekConsumed = foodLogs.fold(
      0.0,
      (double sum, FoodLog f) => sum + f.calories,
    );
    final int foodDays = foodLogs
        .map((FoodLog f) => DateTime(
              f.loggedAt.year,
              f.loggedAt.month,
              f.loggedAt.day,
            ))
        .toSet()
        .length;

    final int workoutScore = _ratioScore(
      monthCount,
      _monthlyWorkoutTarget,
    );
    final int bestCurrentStreak = streaks.fold(
      0,
      (int max, Streak s) =>
          s.currentStreak > max ? s.currentStreak : max,
    );
    final int streakScore = _ratioScore(bestCurrentStreak, 30);
    final int activityScore = _ratioScore(
      weekStepsTotal ~/ 7,
      profile?.targetSteps ?? _defaultStepsTarget,
    );
    final int hydrationScore = _ratioScore(
      weekWaterMl ~/ 7,
      profile?.targetWaterMl ?? _defaultWaterTargetMl,
    );
    final int sleepScore = _ratioScore(
      weekSleepMinutes ~/ 7 ~/ 60,
      _defaultSleepTargetHours,
    );
    final int nutritionScore = _nutritionScore(
      foodDays == 0 ? 0 : weekConsumed / foodDays,
      profile?.targetCalories ?? 0,
    );

    final List<FitnessScoreMetric> metrics = <FitnessScoreMetric>[
      FitnessScoreMetric(
        key: 'workout',
        label: 'workout',
        score: workoutScore,
      ),
      FitnessScoreMetric(
        key: 'consistency',
        label: 'consistency',
        score: streakScore,
      ),
      FitnessScoreMetric(
        key: 'activity',
        label: 'activity',
        score: activityScore,
      ),
      FitnessScoreMetric(
        key: 'hydration',
        label: 'hydration',
        score: hydrationScore,
      ),
      FitnessScoreMetric(
        key: 'sleep',
        label: 'sleep',
        score: sleepScore,
      ),
      FitnessScoreMetric(
        key: 'nutrition',
        label: 'nutrition',
        score: nutritionScore,
      ),
    ];

    final int composite = (workoutScore * 0.25 +
            streakScore * 0.20 +
            activityScore * 0.20 +
            hydrationScore * 0.15 +
            sleepScore * 0.10 +
            nutritionScore * 0.10)
        .round();

    return FitnessScore(
      score: composite.clamp(0, 100),
      label: _gradeFor(composite),
      metrics: metrics,
    );
  }

  // --- helpers ------------------------------------------------------------

  (DateTime, DateTime, AnalyticsGranularity) _windowFor(
    ReportPeriod period,
    DateTime now,
    DateTime? customStart,
    DateTime? customEnd,
  ) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case ReportPeriod.today:
        return (today, today.add(const Duration(days: 1)), AnalyticsGranularity.daily);
      case ReportPeriod.last7Days:
        return (
          today.subtract(const Duration(days: 6)),
          today.add(const Duration(days: 1)),
          AnalyticsGranularity.daily,
        );
      case ReportPeriod.last30Days:
        return (
          today.subtract(const Duration(days: 29)),
          today.add(const Duration(days: 1)),
          AnalyticsGranularity.daily,
        );
      case ReportPeriod.last90Days:
        return (
          today.subtract(const Duration(days: 89)),
          today.add(const Duration(days: 1)),
          AnalyticsGranularity.weekly,
        );
      case ReportPeriod.thisYear:
        final DateTime start = DateTime(now.year, 1, 1);
        final DateTime end = DateTime(now.year + 1, 1, 1);
        return (start, end, AnalyticsGranularity.monthly);
      case ReportPeriod.custom:
        final DateTime start = customStart ?? today.subtract(const Duration(days: 29));
        final DateTime end = customEnd ?? today.add(const Duration(days: 1));
        final int span = end.difference(start).inDays;
        final AnalyticsGranularity granularity = span <= 45
            ? AnalyticsGranularity.daily
            : span <= 250
            ? AnalyticsGranularity.weekly
            : AnalyticsGranularity.monthly;
        return (start, end, granularity);
    }
  }

  /// First day of every bucket covering [start, end).
  List<DateTime> _bucketDays(
    DateTime start,
    DateTime end,
    AnalyticsGranularity granularity,
  ) {
    final List<DateTime> days = <DateTime>[];
    DateTime cursor = start;
    while (cursor.isBefore(end)) {
      days.add(cursor);
      switch (granularity) {
        case AnalyticsGranularity.daily:
          cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
        case AnalyticsGranularity.weekly:
          cursor = cursor.add(const Duration(days: 7));
        case AnalyticsGranularity.monthly:
          cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    }
    return days;
  }

  DateTime _bucketEnd(
    DateTime bucketStart,
    AnalyticsGranularity granularity,
    DateTime rangeEnd,
  ) {
    final DateTime rawEnd = switch (granularity) {
      AnalyticsGranularity.daily => DateTime(
        bucketStart.year,
        bucketStart.month,
        bucketStart.day + 1,
      ),
      AnalyticsGranularity.weekly =>
        bucketStart.add(const Duration(days: 7)),
      AnalyticsGranularity.monthly =>
        DateTime(bucketStart.year, bucketStart.month + 1, 1),
    };
    return rawEnd.isBefore(rangeEnd) ? rawEnd : rangeEnd;
  }

  String _bucketLabel(
    DateTime bucketStart,
    AnalyticsGranularity granularity,
    int index,
  ) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return switch (granularity) {
      AnalyticsGranularity.daily => bucketStart.day.toString(),
      AnalyticsGranularity.weekly => 'W${index + 1}',
      AnalyticsGranularity.monthly => months[bucketStart.month - 1],
    };
  }

  AnalyticsDataPoint _pointFor({
    required DateTime bucketStart,
    required DateTime bucketEnd,
    required AnalyticsGranularity granularity,
    required int bucketIndex,
    required List<WorkoutHistory> workouts,
    required List<WaterLog> waterLogs,
    required List<FoodLog> foodLogs,
    required List<StepLog> stepLogs,
    required List<SleepLog> sleepLogs,
    required List<WeightLog> weightLogs,
    required List<BmiLog> bmiLogs,
    double? carriedWeight,
    double? carriedBmi,
  }) {
    final List<WorkoutHistory> bucketWorkouts = workouts
        .where(
          (WorkoutHistory w) =>
              !w.startedAt.isBefore(bucketStart) &&
              w.startedAt.isBefore(bucketEnd),
        )
        .toList();
    final double caloriesBurned =
        bucketWorkouts.fold<double>(
          0.0,
          (double sum, WorkoutHistory w) => sum + (w.caloriesBurn ?? 0),
        ) +
        stepLogs
            .where(
              (StepLog s) =>
                  !s.stepDate.isBefore(bucketStart) &&
                  s.stepDate.isBefore(bucketEnd),
            )
            .fold<double>(
              0.0,
              (double sum, StepLog s) => sum + s.caloriesBurned,
            );
    final double caloriesConsumed = foodLogs
        .where(
          (FoodLog f) =>
              !f.loggedAt.isBefore(bucketStart) &&
              f.loggedAt.isBefore(bucketEnd),
        )
        .fold(0.0, (double sum, FoodLog f) => sum + f.calories);
    final double workoutMinutes = bucketWorkouts.fold(
      0.0,
      (double sum, WorkoutHistory w) => sum + (w.durationMinutes ?? 0),
    );
    final int waterMl = waterLogs
        .where(
          (WaterLog w) =>
              !w.loggedAt.isBefore(bucketStart) &&
              w.loggedAt.isBefore(bucketEnd),
        )
        .fold(0, (int sum, WaterLog w) => sum + w.amountMl);
    final int steps = stepLogs
        .where(
          (StepLog s) =>
              !s.stepDate.isBefore(bucketStart) &&
              s.stepDate.isBefore(bucketEnd),
        )
        .fold(0, (int sum, StepLog s) => sum + s.steps);
    final double sleepMinutes = sleepLogs
        .where(
          (SleepLog s) =>
              !s.sleepDate.isBefore(bucketStart) &&
              s.sleepDate.isBefore(bucketEnd),
        )
        .fold(0.0, (double sum, SleepLog s) => sum + s.durationMinutes);

    final List<WeightLog> bucketWeights = weightLogs
        .where(
          (WeightLog w) =>
              !w.loggedAt.isBefore(bucketStart) &&
              w.loggedAt.isBefore(bucketEnd),
        )
        .toList();
    final double? weightKg = bucketWeights.isNotEmpty
        ? bucketWeights.last.weightKg
        : carriedWeight;
    final List<BmiLog> bucketBmis = bmiLogs
        .where(
          (BmiLog b) =>
              !b.loggedAt.isBefore(bucketStart) &&
              b.loggedAt.isBefore(bucketEnd),
        )
        .toList();
    final double? bmi = bucketBmis.isNotEmpty ? bucketBmis.last.bmi : carriedBmi;

    return AnalyticsDataPoint(
      date: bucketStart,
      label: _bucketLabel(bucketStart, granularity, bucketIndex),
      caloriesBurned: caloriesBurned,
      caloriesConsumed: caloriesConsumed,
      workoutMinutes: workoutMinutes,
      workoutCount: bucketWorkouts.length,
      waterMl: waterMl,
      steps: steps,
      sleepMinutes: sleepMinutes,
      weightKg: weightKg,
      bmi: bmi,
    );
  }

  AnalyticsSummary _summaryFor({
    required List<WorkoutHistory> workouts,
    required List<WaterLog> waterLogs,
    required List<FoodLog> foodLogs,
    required List<StepLog> stepLogs,
    required List<SleepLog> sleepLogs,
    required List<WeightLog> weightLogs,
    required List<BmiLog> bmiLogs,
  }) {
    final Set<DateTime> workoutDays = <DateTime>{};
    double workoutMinutes = 0;
    double caloriesBurned = 0;
    for (final WorkoutHistory w in workouts) {
      workoutDays.add(DateTime(
        w.startedAt.year,
        w.startedAt.month,
        w.startedAt.day,
      ));
      workoutMinutes += w.durationMinutes ?? 0;
      caloriesBurned += w.caloriesBurn ?? 0;
    }
    caloriesBurned += stepLogs.fold<double>(
      0.0,
      (double sum, StepLog s) => sum + s.caloriesBurned,
    );
    final double caloriesConsumed = foodLogs.fold(
      0.0,
      (double sum, FoodLog f) => sum + f.calories,
    );
    final int waterMl = waterLogs.fold(
      0,
      (int sum, WaterLog w) => sum + w.amountMl,
    );
    final int steps = stepLogs.fold(0, (int sum, StepLog s) => sum + s.steps);
    final double sleepMinutes = sleepLogs.fold(
      0.0,
      (double sum, SleepLog s) => sum + s.durationMinutes,
    );

    final Set<DateTime> activeDays = <DateTime>{
      ...workoutDays,
      ...waterLogs.map(
        (WaterLog w) =>
            DateTime(w.loggedAt.year, w.loggedAt.month, w.loggedAt.day),
      ),
      ...foodLogs.map(
        (FoodLog f) =>
            DateTime(f.loggedAt.year, f.loggedAt.month, f.loggedAt.day),
      ),
      ...stepLogs.map(
        (StepLog s) =>
            DateTime(s.stepDate.year, s.stepDate.month, s.stepDate.day),
      ),
      ...sleepLogs.map(
        (SleepLog s) =>
            DateTime(s.sleepDate.year, s.sleepDate.month, s.sleepDate.day),
      ),
      ...weightLogs.map(
        (WeightLog w) =>
            DateTime(w.loggedAt.year, w.loggedAt.month, w.loggedAt.day),
      ),
    };

    final List<WeightLog> sortedWeights = weightLogs.toList()
      ..sort((WeightLog a, WeightLog b) => a.loggedAt.compareTo(b.loggedAt));
    final List<BmiLog> sortedBmis = bmiLogs.toList()
      ..sort((BmiLog a, BmiLog b) => a.loggedAt.compareTo(b.loggedAt));

    return AnalyticsSummary(
      workoutCount: workouts.length,
      workoutDays: workoutDays.length,
      workoutMinutes: workoutMinutes,
      caloriesBurned: caloriesBurned,
      caloriesConsumed: caloriesConsumed,
      waterMl: waterMl,
      steps: steps,
      sleepMinutes: sleepMinutes,
      activeDays: activeDays.length,
      weightStartKg: sortedWeights.isEmpty
          ? null
          : sortedWeights.first.weightKg,
      weightEndKg: sortedWeights.isEmpty
          ? null
          : sortedWeights.last.weightKg,
      bmiStart: sortedBmis.isEmpty ? null : sortedBmis.first.bmi,
      bmiEnd: sortedBmis.isEmpty ? null : sortedBmis.last.bmi,
    );
  }

  int _streakFor(List<Streak> streaks, StreakType type) {
    for (final Streak streak in streaks) {
      if (streak.streakType == type) return streak.currentStreak;
    }
    return 0;
  }

  double? _explicitWeightTarget(List<FitnessGoal> goals) {
    for (final FitnessGoal goal in goals) {
      if (_isWeightGoal(goal) && goal.targetValue != null) {
        return goal.targetValue;
      }
    }
    return null;
  }

  DateTime? _explicitWeightTargetDate(List<FitnessGoal> goals) {
    for (final FitnessGoal goal in goals) {
      if (_isWeightGoal(goal) && goal.targetDate != null) {
        return goal.targetDate;
      }
    }
    return null;
  }

  double? _explicitWorkoutTarget(List<FitnessGoal> goals) {
    for (final FitnessGoal goal in goals) {
      if (!_isWeightGoal(goal) && goal.targetValue != null) {
        return goal.targetValue;
      }
    }
    return null;
  }

  bool _isWeightGoal(FitnessGoal goal) {
    return switch (goal.goalType) {
      GoalType.weightLoss ||
      GoalType.weightGain ||
      GoalType.maintainWeight => true,
      GoalType.muscleBuilding || GoalType.generalFitness || GoalType.other =>
        false,
    };
  }

  int _ratioScore(num current, num target) {
    if (target <= 0) return 0;
    final double ratio = current / target * 100;
    return ratio.round().clamp(0, 100);
  }

  int _nutritionScore(double avgConsumed, double target) {
    if (target <= 0 || avgConsumed <= 0) return 0;
    final double ratio = avgConsumed / target;
    if (ratio >= 0.9 && ratio <= 1.1) return 100;
    if (ratio < 0.9) return (ratio / 0.9 * 100).round().clamp(0, 100);
    final double over = ratio - 1.1;
    return (100 - over / 0.4 * 100).round().clamp(0, 100);
  }

  String _gradeFor(int score) {
    if (score >= 80) return 'excellent';
    if (score >= 60) return 'good';
    if (score >= 40) return 'fair';
    if (score >= 20) return 'needsWork';
    return 'gettingStarted';
  }

  bool _inRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && value.isBefore(end);
  }

  T? _maxBy<T>(Iterable<T> items, double Function(T) valueOf) {
    T? best;
    double bestValue = double.negativeInfinity;
    for (final T item in items) {
      final double value = valueOf(item);
      if (value > bestValue) {
        bestValue = value;
        best = item;
      }
    }
    return best;
  }

  T? _minBy<T>(Iterable<T> items, double Function(T) valueOf) {
    T? best;
    double bestValue = double.infinity;
    for (final T item in items) {
      final double value = valueOf(item);
      if (value < bestValue) {
        bestValue = value;
        best = item;
      }
    }
    return best;
  }
}
