import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/badge_local_data_source.dart';
import 'package:nexfit/data/datasources/local/bmi_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/food_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/level_local_data_source.dart';
import 'package:nexfit/data/datasources/local/reminder_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sleep_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/step_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/streak_local_data_source.dart';
import 'package:nexfit/data/datasources/local/user_profile_local_data_source.dart';
import 'package:nexfit/data/datasources/local/water_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/weight_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_history_local_data_source.dart';
import 'package:nexfit/data/repositories/badge_repository_impl.dart';
import 'package:nexfit/data/repositories/bmi_log_repository_impl.dart';
import 'package:nexfit/data/repositories/dashboard_repository_impl.dart';
import 'package:nexfit/data/repositories/food_log_repository_impl.dart';
import 'package:nexfit/data/repositories/level_repository_impl.dart';
import 'package:nexfit/data/repositories/reminder_repository_impl.dart';
import 'package:nexfit/data/repositories/sleep_log_repository_impl.dart';
import 'package:nexfit/data/repositories/step_log_repository_impl.dart';
import 'package:nexfit/data/repositories/streak_repository_impl.dart';
import 'package:nexfit/data/repositories/user_fitness_profile_repository_impl.dart';
import 'package:nexfit/data/repositories/water_log_repository_impl.dart';
import 'package:nexfit/data/repositories/weight_log_repository_impl.dart';
import 'package:nexfit/data/repositories/workout_history_repository_impl.dart';
import 'package:nexfit/domain/entities/badge.dart';
import 'package:nexfit/domain/entities/common_enums.dart';
import 'package:nexfit/domain/entities/dashboard_data.dart';
import 'package:nexfit/domain/entities/food_log.dart';
import 'package:nexfit/domain/entities/level.dart';
import 'package:nexfit/domain/entities/sleep_log.dart';
import 'package:nexfit/domain/entities/step_log.dart';
import 'package:nexfit/domain/entities/streak.dart';
import 'package:nexfit/domain/entities/water_log.dart';
import 'package:nexfit/domain/entities/weight_log.dart';
import 'package:nexfit/domain/entities/workout_history.dart';

/// PROMPT 28 — Dashboard UX finalization.
///
/// The dashboard aggregate now reads bounded 7-day windows for the activity
/// tables while preserving the full-history meaning of `hasWeight` /
/// `hasWorkouts` (via `getLatest` / `countCompleted`), surfaces the last
/// logged night's sleep and lifetime XP, and exposes `getByDateRange` on the
/// sleep and step repositories (which power the new sleep logger and weekly
/// charts).
///
/// See `docs/NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §28.

class _Harness {
  _Harness(this.db);

  final AppDatabase db;

  late final WorkoutHistoryRepositoryImpl workoutHistory;
  late final WaterLogRepositoryImpl waterLog;
  late final FoodLogRepositoryImpl foodLog;
  late final WeightLogRepositoryImpl weightLog;
  late final SleepLogRepositoryImpl sleepLog;
  late final StepLogRepositoryImpl stepLog;
  late final BmiLogRepositoryImpl bmiLog;
  late final StreakRepositoryImpl streak;
  late final BadgeRepositoryImpl badge;
  late final ReminderRepositoryImpl reminder;
  late final UserFitnessProfileRepositoryImpl profile;
  late final LevelRepositoryImpl level;

  late final DashboardRepositoryImpl dashboard;

  Future<void> init() async {
    final raw = await db.database;
    await raw.insert('users', <String, Object?>{
      'id': 'u-1',
      'name': 'Rahim',
      'email': 'rahim@example.com',
      'provider': 'email',
    });

    workoutHistory = WorkoutHistoryRepositoryImpl(
      WorkoutHistoryLocalDataSource(database: db),
    );
    waterLog = WaterLogRepositoryImpl(
      WaterLogLocalDataSource(database: db),
    );
    foodLog = FoodLogRepositoryImpl(
      FoodLogLocalDataSource(database: db),
    );
    weightLog = WeightLogRepositoryImpl(
      WeightLogLocalDataSource(database: db),
    );
    sleepLog = SleepLogRepositoryImpl(
      SleepLogLocalDataSource(database: db),
    );
    stepLog = StepLogRepositoryImpl(
      StepLogLocalDataSource(database: db),
    );
    bmiLog = BmiLogRepositoryImpl(
      BmiLogLocalDataSource(database: db),
    );
    streak = StreakRepositoryImpl(
      StreakLocalDataSource(database: db),
    );
    badge = BadgeRepositoryImpl(
      BadgeLocalDataSource(database: db),
    );
    reminder = ReminderRepositoryImpl(
      ReminderLocalDataSource(database: db),
    );
    profile = UserFitnessProfileRepositoryImpl(
      UserProfileLocalDataSource(database: db),
    );
    level = LevelRepositoryImpl(
      LevelLocalDataSource(database: db),
    );

    dashboard = DashboardRepositoryImpl(
      workoutHistoryRepository: workoutHistory,
      waterLogRepository: waterLog,
      stepLogRepository: stepLog,
      weightLogRepository: weightLog,
      bmiLogRepository: bmiLog,
      foodLogRepository: foodLog,
      sleepLogRepository: sleepLog,
      streakRepository: streak,
      badgeRepository: badge,
      reminderRepository: reminder,
      userFitnessProfileRepository: profile,
      levelRepository: level,
    );
  }

  Future<void> close() => db.close();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late _Harness harness;

  setUp(() async {
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/dashboard_finalization.db',
    );
    harness = _Harness(AppDatabase(databaseName: 'dashboard_finalization.db'));
    await harness.init();
  });

  tearDown(() async {
    await harness.close();
  });

  DateTime dayOf(DateTime now, [int daysAgo = 0]) {
    final DateTime base = DateTime(now.year, now.month, now.day);
    return base.subtract(Duration(days: daysAgo));
  }

  group('PROMPT 28 dashboard finalization', () {
    test('sleep metric comes from the most recent logged night in the window',
        () async {
      final DateTime now = DateTime.now();
      await harness.sleepLog.insert(
        SleepLog(
          userId: 'u-1',
          sleepDate: dayOf(now, 1),
          durationMinutes: 480,
          quality: 4,
          createdAt: now,
        ),
      );
      await harness.sleepLog.insert(
        SleepLog(
          userId: 'u-1',
          sleepDate: dayOf(now, 10),
          durationMinutes: 420,
          quality: 2,
          createdAt: now,
        ),
      );

      final DashboardData data = await harness.dashboard.loadDashboard(
        'u-1',
        now,
      );

      expect(data.summary.hasSleep, isTrue);
      expect(data.summary.sleepMinutes, 480);
      expect(
        data.recentActivity.any(
          (RecentActivityItem item) =>
              item.kind == DashboardActivityKind.sleep,
        ),
        isTrue,
      );
    });

    test('sleep stays empty when the only entry predates the 7-day window',
        () async {
      final DateTime now = DateTime.now();
      await harness.sleepLog.insert(
        SleepLog(
          userId: 'u-1',
          sleepDate: dayOf(now, 10),
          durationMinutes: 420,
          createdAt: now,
        ),
      );

      final DashboardData data = await harness.dashboard.loadDashboard(
        'u-1',
        now,
      );

      expect(data.summary.hasSleep, isFalse);
      expect(data.summary.sleepMinutes, 0);
    });

    test('totalXp surfaces the user_level singleton', () async {
      final DateTime now = DateTime.now();
      await harness.level.upsert(
        LevelProgress(
          userId: 'u-1',
          level: 5,
          currentXp: 234,
          requiredXp: 500,
          totalXp: 1234,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final DashboardData data = await harness.dashboard.loadDashboard(
        'u-1',
        now,
      );

      expect(data.summary.totalXp, 1234);
    });

    test('totalXp is zero when no level row exists yet', () async {
      final DateTime now = DateTime.now();

      final DashboardData data = await harness.dashboard.loadDashboard(
        'u-1',
        now,
      );

      expect(data.summary.totalXp, 0);
    });

    test('hasWeight keeps its full-history meaning while charts stay bounded',
        () async {
      final DateTime now = DateTime.now();
      await harness.weightLog.insert(
        WeightLog(
          userId: 'u-1',
          weightKg: 70.5,
          loggedAt: dayOf(now, 10),
          createdAt: now,
        ),
      );

      DashboardData data = await harness.dashboard.loadDashboard('u-1', now);
      expect(data.summary.hasWeight, isTrue);
      expect(data.summary.weightKg, 70.5);
      expect(
        data.weeklyWeight.every(
          (WeeklyStatPoint point) => point.value == 0,
        ),
        isTrue,
      );

      await harness.weightLog.insert(
        WeightLog(
          userId: 'u-1',
          weightKg: 72.0,
          loggedAt: dayOf(now, 1),
          createdAt: now,
        ),
      );
      data = await harness.dashboard.loadDashboard('u-1', now);
      expect(data.summary.weightKg, 72.0);
      expect(
        data.weeklyWeight
            .firstWhere((WeeklyStatPoint p) => p.date == dayOf(now, 1))
            .value,
        72.0,
      );
    });

    test('hasWorkouts counts completed workouts from all history', () async {
      final DateTime now = DateTime.now();
      await harness.workoutHistory.insert(
        WorkoutHistory(
          userId: 'u-1',
          startedAt: dayOf(now, 10),
          endedAt: dayOf(now, 10).add(const Duration(minutes: 30)),
          durationMinutes: 30,
          caloriesBurn: 200,
          isCompleted: true,
          createdAt: now,
        ),
      );

      DashboardData data = await harness.dashboard.loadDashboard('u-1', now);
      expect(data.summary.hasWorkouts, isTrue);
      expect(
        data.weeklyWorkout.every((WeeklyStatPoint p) => p.value == 0),
        isTrue,
      );

      await harness.workoutHistory.insert(
        WorkoutHistory(
          userId: 'u-1',
          startedAt: dayOf(now, 2),
          endedAt: dayOf(now, 2).add(const Duration(minutes: 40)),
          durationMinutes: 40,
          caloriesBurn: 300,
          isCompleted: true,
          createdAt: now,
        ),
      );
      data = await harness.dashboard.loadDashboard('u-1', now);
      expect(
        data.weeklyWorkout
            .firstWhere((WeeklyStatPoint p) => p.date == dayOf(now, 2))
            .value,
        40,
      );
      expect(
        data.recentActivity.any(
          (RecentActivityItem item) =>
              item.kind == DashboardActivityKind.workout,
        ),
        isTrue,
      );
    });

    test('today aggregates and weekly charts are bounded to the window',
        () async {
      final DateTime now = DateTime.now();
      await harness.waterLog.insert(
        WaterLog(
          userId: 'u-1',
          amountMl: 500,
          loggedAt: now,
          createdAt: now,
        ),
      );
      await harness.waterLog.insert(
        WaterLog(
          userId: 'u-1',
          amountMl: 250,
          loggedAt: dayOf(now, 10),
          createdAt: now,
        ),
      );
      await harness.foodLog.insert(
        FoodLog(
          userId: 'u-1',
          calories: 300,
          loggedAt: now,
          createdAt: now,
        ),
      );
      await harness.foodLog.insert(
        FoodLog(
          userId: 'u-1',
          calories: 100,
          loggedAt: dayOf(now, 10),
          createdAt: now,
        ),
      );
      await harness.stepLog.insert(
        StepLog(
          userId: 'u-1',
          stepDate: dayOf(now),
          steps: 5000,
          distanceKm: 3.8,
          caloriesBurned: 150,
          createdAt: now,
        ),
      );
      await harness.stepLog.insert(
        StepLog(
          userId: 'u-1',
          stepDate: dayOf(now, 10),
          steps: 2000,
          createdAt: now,
        ),
      );

      final DashboardData data = await harness.dashboard.loadDashboard(
        'u-1',
        now,
      );

      expect(data.summary.waterMl, 500);
      expect(data.goals.waterMl, 500);
      expect(data.goals.caloriesConsumed, 300);
      expect(data.summary.steps, 5000);
      expect(data.goals.steps, 5000);
      expect(data.summary.hasActivity, isTrue);
      expect(
        data.weeklyWater
            .firstWhere((WeeklyStatPoint p) => p.date == dayOf(now))
            .value,
        500,
      );
    });

    test('best workout streak still drives the summary and achievement',
        () async {
      final DateTime now = DateTime.now();
      await harness.streak.upsert(
        Streak(
          userId: 'u-1',
          streakType: StreakType.workout,
          currentStreak: 5,
          longestStreak: 9,
          lastActiveDate: dayOf(now),
          bestDate: dayOf(now, 4),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await harness.badge.insert(
        Badge(
          userId: 'u-1',
          badgeType: 'workout',
          badgeName: 'Iron',
          isEarned: true,
          earnedAt: dayOf(now, 2),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final DashboardData data = await harness.dashboard.loadDashboard(
        'u-1',
        now,
      );

      expect(data.summary.workoutStreak, 5);
      expect(data.achievement.currentStreak, 5);
      expect(data.achievement.streakType, StreakType.workout);
      expect(data.achievement.hasBadges, isTrue);
      expect(data.achievement.badgeName, 'Iron');
    });

    test('sleep repository exposes a working getByDateRange', () async {
      final DateTime now = DateTime.now();
      await harness.sleepLog.insert(
        SleepLog(
          userId: 'u-1',
          sleepDate: dayOf(now, 2),
          durationMinutes: 450,
          createdAt: now,
        ),
      );
      await harness.sleepLog.insert(
        SleepLog(
          userId: 'u-1',
          sleepDate: dayOf(now, 15),
          durationMinutes: 480,
          createdAt: now,
        ),
      );

      final DateTime windowStart = dayOf(now, 7);
      final DateTime windowEnd = dayOf(now).add(const Duration(days: 1));
      final List<SleepLog> inRange = await harness.sleepLog.getByDateRange(
        'u-1',
        windowStart,
        windowEnd,
      );

      expect(inRange.length, 1);
      expect(inRange.first.sleepDate, dayOf(now, 2));
    });

    test('step repository exposes a working getByDateRange', () async {
      final DateTime now = DateTime.now();
      await harness.stepLog.insert(
        StepLog(
          userId: 'u-1',
          stepDate: dayOf(now),
          steps: 6000,
          createdAt: now,
        ),
      );
      await harness.stepLog.insert(
        StepLog(
          userId: 'u-1',
          stepDate: dayOf(now, 20),
          steps: 1000,
          createdAt: now,
        ),
      );

      final DateTime windowStart = dayOf(now, 7);
      final DateTime windowEnd = dayOf(now).add(const Duration(days: 1));
      final List<StepLog> inRange = await harness.stepLog.getByDateRange(
        'u-1',
        windowStart,
        windowEnd,
      );

      expect(inRange.length, 1);
      expect(inRange.first.stepDate, dayOf(now));
    });

    test('an in-progress workout alone does not count as having workouts',
        () async {
      final DateTime now = DateTime.now();
      await harness.workoutHistory.insert(
        WorkoutHistory(
          userId: 'u-1',
          startedAt: now,
          isCompleted: false,
          createdAt: now,
        ),
      );

      final DashboardData data = await harness.dashboard.loadDashboard(
        'u-1',
        now,
      );

      expect(data.summary.hasWorkouts, isFalse);
      expect(data.summary.hasActivity, isTrue);
    });
  });
}