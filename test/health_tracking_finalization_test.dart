import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexfit/core/utils/date_formatting.dart';
import 'package:nexfit/core/utils/sleep_stats.dart';
import 'package:nexfit/core/utils/step_estimator.dart';
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
import 'package:nexfit/domain/entities/app_user.dart';
import 'package:nexfit/domain/entities/common_enums.dart';
import 'package:nexfit/domain/entities/daily_hydration.dart';
import 'package:nexfit/domain/entities/dashboard_data.dart';
import 'package:nexfit/domain/entities/reminder.dart';
import 'package:nexfit/domain/entities/sleep_log.dart';
import 'package:nexfit/domain/entities/step_log.dart';
import 'package:nexfit/domain/entities/water_history.dart';
import 'package:nexfit/domain/entities/water_log.dart';
import 'package:nexfit/domain/entities/water_statistics.dart';
import 'package:nexfit/domain/repositories/hydration_repository.dart';
import 'package:nexfit/injection/dependency_injection.dart';
import 'package:nexfit/l10n/app_localizations_bs.dart';
import 'package:nexfit/l10n/app_localizations_en.dart';
import 'package:nexfit/presentation/providers/auth_provider.dart';
import 'package:nexfit/presentation/providers/sleep_providers.dart';
import 'package:nexfit/presentation/providers/water_providers.dart';

/// PROMPT 31 — Health tracking finalization.
///
/// The water reminders screen was showing every reminder type (the shared
/// reminder table leaked workout / sleep / meal reminders into the hydration
/// module), the weight hero ring was a dead visual with no way to set the goal
/// from the tracker, the dashboard BMI sheet ignored the profile height,
/// steps had no write path at all (no pedometer integration, so a manual log
/// is the correct fit), sleep had no history screen, and every water/weight
/// chart hardcoded English month names that leaked into the Bangla UI.
///
/// See `docs/NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §27.

/// Minimal fake hydration repository used to prove the water reminder filter.
class _FakeHydrationRepository implements HydrationRepository {
  _FakeHydrationRepository(this.reminders);

  final List<Reminder> reminders;

  @override
  Future<List<Reminder>> getReminders(String userId) async => reminders;

  @override
  Future<DailyHydration> loadDaily(String userId, DateTime date) =>
      throw UnimplementedError();

  @override
  Future<WaterHistory> loadHistory(String userId, WaterHistoryPeriod period) =>
      throw UnimplementedError();

  @override
  Future<WaterStatistics> loadStatistics(String userId) =>
      throw UnimplementedError();

  @override
  Future<int> getGoal(String userId) => throw UnimplementedError();

  @override
  Future<void> setGoal(String userId, int goalMl) =>
      throw UnimplementedError();

  @override
  Future<int> addEntry(
    String userId,
    int amountMl, {
    DateTime? date,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<void> updateEntry(WaterLog log) => throw UnimplementedError();

  @override
  Future<void> deleteEntry(int id) => throw UnimplementedError();

  @override
  Future<int> addReminder(Reminder reminder) => throw UnimplementedError();

  @override
  Future<void> updateReminder(Reminder reminder) =>
      throw UnimplementedError();

  @override
  Future<void> deleteReminder(int id) => throw UnimplementedError();

  @override
  Future<void> rescheduleAll(String userId) => throw UnimplementedError();
}

class _Harness {
  _Harness(this.db);

  final AppDatabase db;

  late final StepLogRepositoryImpl stepLog;
  late final SleepLogRepositoryImpl sleepLog;
  late final DashboardRepositoryImpl dashboard;

  Future<void> init() async {
    final raw = await db.database;
    await raw.insert('users', <String, Object?>{
      'id': 'u-1',
      'name': 'Rahim',
      'email': 'rahim@example.com',
      'provider': 'email',
    });

    stepLog = StepLogRepositoryImpl(
      StepLogLocalDataSource(database: db),
    );
    sleepLog = SleepLogRepositoryImpl(
      SleepLogLocalDataSource(database: db),
    );

    final workoutHistory = WorkoutHistoryRepositoryImpl(
      WorkoutHistoryLocalDataSource(database: db),
    );
    final waterLog = WaterLogRepositoryImpl(
      WaterLogLocalDataSource(database: db),
    );
    final foodLog = FoodLogRepositoryImpl(
      FoodLogLocalDataSource(database: db),
    );
    final weightLog = WeightLogRepositoryImpl(
      WeightLogLocalDataSource(database: db),
    );
    final bmiLog = BmiLogRepositoryImpl(
      BmiLogLocalDataSource(database: db),
    );
    final streak = StreakRepositoryImpl(
      StreakLocalDataSource(database: db),
    );
    final badge = BadgeRepositoryImpl(
      BadgeLocalDataSource(database: db),
    );
    final reminder = ReminderRepositoryImpl(
      ReminderLocalDataSource(database: db),
    );
    final profile = UserFitnessProfileRepositoryImpl(
      UserProfileLocalDataSource(database: db),
    );
    final level = LevelRepositoryImpl(
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
      '${await databaseFactory.getDatabasesPath()}/health_tracking_finalization.db',
    );
    harness = _Harness(
      AppDatabase(databaseName: 'health_tracking_finalization.db'),
    );
    await harness.init();
  });

  tearDown(() async {
    await harness.close();
  });

  DateTime dayOf(DateTime now, [int daysAgo = 0]) {
    final DateTime base = DateTime(now.year, now.month, now.day);
    return base.subtract(Duration(days: daysAgo));
  }

  const AppUser signedIn = AppUser(
    id: 'u-1',
    email: 'rahim@example.com',
    isEmailVerified: true,
    provider: AuthProvider.email,
  );

  ProviderContainer signedInContainer({
    List<Override>? extraOverrides,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        currentUserProvider.overrideWithValue(signedIn),
        ...?extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('PROMPT 31 health tracking', () {
    test('water reminders provider filters to water-type reminders', () async {
      final DateTime now = DateTime.now();
      final Reminder water = Reminder(
        userId: 'u-1',
        title: 'Drink water',
        reminderType: ReminderType.water,
        time: '08:00',
        createdAt: now,
        updatedAt: now,
      );
      final Reminder sleep = Reminder(
        userId: 'u-1',
        title: 'Sleep reminder',
        reminderType: ReminderType.sleep,
        time: '22:00',
        createdAt: now,
        updatedAt: now,
      );
      final Reminder workout = Reminder(
        userId: 'u-1',
        title: 'Workout reminder',
        reminderType: ReminderType.workout,
        time: '17:00',
        createdAt: now,
        updatedAt: now,
      );

      final ProviderContainer container = signedInContainer(
        extraOverrides: <Override>[
          hydrationRepositoryProvider.overrideWithValue(
            _FakeHydrationRepository(<Reminder>[water, sleep, workout]),
          ),
        ],
      );

      final List<Reminder> reminders =
          await container.read(waterRemindersProvider.future);

      expect(reminders, <Reminder>[water]);
      expect(
        reminders.every(
          (Reminder r) => r.reminderType == ReminderType.water,
        ),
        isTrue,
      );
    });

    test('sleep history provider returns records newest first', () async {
      final DateTime now = DateTime.now();
      await harness.sleepLog.insert(
        SleepLog(
          userId: 'u-1',
          sleepDate: dayOf(now, 10),
          durationMinutes: 420,
          createdAt: now,
        ),
      );
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
          sleepDate: dayOf(now),
          durationMinutes: 480,
          createdAt: now,
        ),
      );

      final ProviderContainer container = signedInContainer(
        extraOverrides: <Override>[
          sleepLogRepositoryProvider.overrideWithValue(harness.sleepLog),
        ],
      );

      final List<SleepLog> logs = await container.read(
        sleepHistoryProvider.future,
      );

      expect(logs.length, 3);
      expect(logs[0].sleepDate, dayOf(now));
      expect(logs[1].sleepDate, dayOf(now, 2));
      expect(logs[2].sleepDate, dayOf(now, 10));
    });

    test('a manually logged step entry drives the dashboard summary', () async {
      final DateTime now = DateTime.now();
      await harness.stepLog.insert(
        StepLog(
          userId: 'u-1',
          stepDate: dayOf(now),
          steps: 8500,
          distanceKm: StepEstimator.distanceKm(8500),
          caloriesBurned: StepEstimator.caloriesBurned(8500),
          createdAt: now,
        ),
      );

      final DashboardData data = await harness.dashboard.loadDashboard(
        'u-1',
        now,
      );

      expect(data.summary.steps, 8500);
      expect(data.summary.hasActivity, isTrue);
    });

    test('StepEstimator derives distance and calories from steps', () {
      expect(StepEstimator.distanceKm(10000), closeTo(7.62, 0.0001));
      expect(StepEstimator.caloriesBurned(10000), 400);
      expect(StepEstimator.distanceKm(0), 0);
      expect(StepEstimator.caloriesBurned(0), 0);
    });

    test('SleepStats aggregates nights, average duration and quality', () {
      final List<SleepLog> logs = <SleepLog>[
        SleepLog(
          userId: 'u-1',
          sleepDate: DateTime(2026, 8, 14),
          durationMinutes: 480,
          quality: 4,
          createdAt: DateTime(2026, 8, 14),
        ),
        SleepLog(
          userId: 'u-1',
          sleepDate: DateTime(2026, 8, 13),
          durationMinutes: 420,
          quality: 2,
          createdAt: DateTime(2026, 8, 13),
        ),
      ];

      final SleepStats stats = SleepStats.from(logs);

      expect(stats.nights, 2);
      expect(stats.avgDurationMinutes, 450);
      expect(stats.avgQuality, 3);
      expect(SleepStats.from(<SleepLog>[]).nights, 0);
    });

    test('localized month and date helpers render en and bs', () {
      final AppLocalizationsEn en = AppLocalizationsEn();
      final AppLocalizationsBs bs = AppLocalizationsBs();

      expect(localizedMonth(en, 8), 'Aug');
      expect(localizedMonth(bs, 8), 'আগস্ট');
      expect(localizedMonth(en, 12), 'Dec');
      expect(
        formatLocalizedDate(DateTime(2026, 8, 15), en),
        '15 Aug 2026',
      );
      expect(
        formatLocalizedDate(DateTime(2026, 8, 15), bs),
        '১৫ আগস্ট ২০২৬',
      );
    });
  });
}