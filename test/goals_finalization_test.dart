import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/bmi_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/fitness_goal_local_data_source.dart';
import 'package:nexfit/data/datasources/local/food_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sleep_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/step_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/streak_local_data_source.dart';
import 'package:nexfit/data/datasources/local/user_profile_local_data_source.dart';
import 'package:nexfit/data/datasources/local/water_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/weight_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_history_local_data_source.dart';
import 'package:nexfit/data/repositories/bmi_log_repository_impl.dart';
import 'package:nexfit/data/repositories/fitness_goal_repository_impl.dart';
import 'package:nexfit/data/repositories/food_log_repository_impl.dart';
import 'package:nexfit/data/repositories/progress_analytics_repository_impl.dart';
import 'package:nexfit/data/repositories/sleep_log_repository_impl.dart';
import 'package:nexfit/data/repositories/step_log_repository_impl.dart';
import 'package:nexfit/data/repositories/streak_repository_impl.dart';
import 'package:nexfit/data/repositories/user_fitness_profile_repository_impl.dart';
import 'package:nexfit/data/repositories/water_log_repository_impl.dart';
import 'package:nexfit/data/repositories/weight_log_repository_impl.dart';
import 'package:nexfit/data/repositories/workout_history_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_contracts.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/domain/entities/app_user.dart';
import 'package:nexfit/domain/entities/common_enums.dart';
import 'package:nexfit/domain/entities/fitness_goal.dart';
import 'package:nexfit/domain/entities/progress/goal_progress.dart';
import 'package:nexfit/domain/entities/streak.dart';
import 'package:nexfit/domain/entities/water_log.dart';
import 'package:nexfit/domain/entities/weight_log.dart';
import 'package:nexfit/domain/entities/workout_history.dart';
import 'package:nexfit/domain/repositories/fitness_goal_repository.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/injection/dependency_injection.dart';
import 'package:nexfit/presentation/providers/auth_provider.dart';
import 'package:nexfit/presentation/providers/fitness_goal_providers.dart';

/// PROMPT 32 — Fitness goals & progress finalization.
///
/// The goal progress screen now shows the remaining amount and the live
/// streak for every kind backed by real records, marks goals as reached, and
/// exposes a goal management screen that creates user-owned goals from the
/// server-authoritative templates. All create/update/delete flows run through
/// the existing sync-aware DAO (transactional outbox events, row versions,
/// soft deletes) so goals propagate offline-first and never echo loops.
///
/// See `docs/NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §28.

class _Harness {
  _Harness(this.db);

  final AppDatabase db;

  late final FitnessGoalRepository goals;
  late final ProgressAnalyticsRepositoryImpl analytics;
  late final StreakRepositoryImpl streaks;
  late final WorkoutHistoryRepositoryImpl workoutHistory;
  late final WaterLogRepositoryImpl waterLog;
  late final WeightLogRepositoryImpl weightLog;

  Future<void> init() async {
    final raw = await db.database;
    await raw.insert('users', <String, Object?>{
      'id': 'u-1',
      'name': 'Rahim',
      'email': 'rahim@example.com',
      'provider': 'email',
    });
    await raw.insert('users', <String, Object?>{
      'id': 'u-2',
      'name': 'Karim',
      'email': 'karim@example.com',
      'provider': 'email',
    });

    workoutHistory = WorkoutHistoryRepositoryImpl(
      WorkoutHistoryLocalDataSource(database: db),
    );
    waterLog = WaterLogRepositoryImpl(WaterLogLocalDataSource(database: db));
    weightLog = WeightLogRepositoryImpl(WeightLogLocalDataSource(database: db));
    final sleepLog = SleepLogRepositoryImpl(
      SleepLogLocalDataSource(database: db),
    );
    final stepLog = StepLogRepositoryImpl(StepLogLocalDataSource(database: db));
    streaks = StreakRepositoryImpl(StreakLocalDataSource(database: db));
    final profile = UserFitnessProfileRepositoryImpl(
      UserProfileLocalDataSource(database: db),
    );
    goals = FitnessGoalRepositoryImpl(FitnessGoalLocalDataSource(database: db));

    analytics = ProgressAnalyticsRepositoryImpl(
      workoutHistoryRepository: workoutHistory,
      waterLogRepository: waterLog,
      foodLogRepository: FoodLogRepositoryImpl(
        FoodLogLocalDataSource(database: db),
      ),
      weightLogRepository: weightLog,
      bmiLogRepository: BmiLogRepositoryImpl(
        BmiLogLocalDataSource(database: db),
      ),
      sleepLogRepository: sleepLog,
      stepLogRepository: stepLog,
      streakRepository: streaks,
      fitnessGoalRepository: goals,
      userFitnessProfileRepository: profile,
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
      '${await databaseFactory.getDatabasesPath()}/goals_finalization.db',
    );
    harness = _Harness(
      AppDatabase(databaseName: 'goals_finalization.db'),
    );
    await harness.init();
    SyncEventRecorder.configure(
      repository: SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: harness.db),
      ),
      deviceIdProvider: () async => 'device-1',
    );
  });

  tearDown(() async {
    SyncEventRecorder.setEnabled(false);
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

  Future<void> insertWorkout(DateTime now, int daysAgo) async {
    final DateTime started = DateTime(
      now.year,
      now.month,
      now.day,
      7,
    ).subtract(Duration(days: daysAgo));
    await harness.workoutHistory.insert(
      WorkoutHistory(
        userId: 'u-1',
        startedAt: started,
        endedAt: started.add(const Duration(minutes: 45)),
        durationMinutes: 45,
        isCompleted: true,
        createdAt: started,
      ),
    );
  }

  Future<FitnessGoal> weightLossTemplate() async {
    final List<FitnessGoal> templates = await harness.goals.getTemplates();
    return templates.firstWhere(
      (FitnessGoal t) => t.goalType == GoalType.weightLoss,
    );
  }

  Future<void> applyRemoteUpdate(String uuid) async {
    final RemoteChangeApplier applier = RemoteChangeApplier(database: harness.db);
    final raw = await harness.db.database;
    await raw.transaction((txn) async {
      await applier.apply(
        txn,
        SyncChange(
          cursorId: 1,
          cloudTable: 'fitness_goals',
          recordId: uuid,
          operation: SyncOperation.update,
          payload: <String, Object?>{
            'id': uuid,
            'user_id': 'u-1',
            'title': 'Lose weight',
            'goal_type': GoalType.weightLoss.name,
            'status': GoalStatus.active.name,
            'target_value': 80,
            'current_value': 0,
            'row_version': 7,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ),
      );
    });
  }

  group('PROMPT 32 fitness goals', () {
    test('creating a user goal persists it and generates a sync event',
        () async {
      final DateTime now = DateTime.now();
      final int id = await harness.goals.insert(
        FitnessGoal(
          userId: 'u-1',
          title: 'Weight Loss',
          goalType: GoalType.weightLoss,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final FitnessGoal? loaded = await harness.goals.getById(id);
      expect(loaded, isNotNull);
      expect(loaded!.userId, 'u-1');
      expect(loaded.goalType, GoalType.weightLoss);
      expect(loaded.status, GoalStatus.active);

      final raw = await harness.db.database;
      final List<Map<String, Object?>> events = await raw.query(
        'sync_event',
        where: 'entity = ? AND entity_id = ?',
        whereArgs: <Object?>['fitness_goal', '$id'],
      );
      expect(events, hasLength(1));
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['status'], SyncStatus.pending.name);
      expect(events.single['base_version'], 0);
      expect(events.single['user_id'], 'u-1');
    });

    test('templates are master data and never carry a user id', () async {
      final List<FitnessGoal> templates = await harness.goals.getTemplates();
      expect(templates, isNotEmpty);
      expect(templates.every((FitnessGoal t) => t.userId == null), isTrue);
      expect(
        templates.map((FitnessGoal t) => t.goalType),
        containsAll(<GoalType>[
          GoalType.weightLoss,
          GoalType.weightGain,
          GoalType.maintainWeight,
        ]),
      );
    });

    test('adopting a template copies master data into a user-owned goal',
        () async {
      final int before = (await harness.goals.getTemplates()).length;
      final FitnessGoal template = await weightLossTemplate();
      final DateTime now = DateTime.now();

      await harness.goals.insert(
        FitnessGoal(
          userId: 'u-1',
          title: template.title,
          description: template.description,
          goalType: template.goalType,
          startDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final ProviderContainer container = signedInContainer(
        extraOverrides: <Override>[
          fitnessGoalRepositoryProvider.overrideWithValue(harness.goals),
        ],
      );
      final List<FitnessGoal> mine =
          await container.read(userGoalsProvider.future);
      expect(mine, hasLength(1));
      expect(mine.single.goalType, GoalType.weightLoss);
      expect(mine.single.userId, 'u-1');
      // The master template is untouched.
      expect(
        (await harness.goals.getTemplates()).length,
        before,
      );
    });

    test('updating a goal bumps row version and records an UPDATE event',
        () async {
      final DateTime now = DateTime.now();
      final int id = await harness.goals.insert(
        FitnessGoal(
          userId: 'u-1',
          title: 'Weight Loss',
          goalType: GoalType.weightLoss,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await harness.goals.update(
        FitnessGoal(
          id: id,
          userId: 'u-1',
          title: 'Weight Loss',
          goalType: GoalType.weightLoss,
          targetValue: 70,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final FitnessGoal? loaded = await harness.goals.getById(id);
      expect(loaded!.targetValue, 70);

      final raw = await harness.db.database;
      final List<Map<String, Object?>> events = await raw.query(
        'sync_event',
        where: 'entity = ? AND entity_id = ?',
        whereArgs: <Object?>['fitness_goal', '$id'],
        orderBy: 'id ASC',
      );
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('completion marks the goal completed without losing sync metadata',
        () async {
      final DateTime now = DateTime.now();
      final int id = await harness.goals.insert(
        FitnessGoal(
          userId: 'u-1',
          title: 'Weight Gain',
          goalType: GoalType.weightGain,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await harness.goals.update(
        (await harness.goals.getById(id))!.copyWith(
          status: GoalStatus.completed,
          updatedAt: DateTime.now(),
        ),
      );

      final FitnessGoal? loaded = await harness.goals.getById(id);
      expect(loaded!.status, GoalStatus.completed);

      final raw = await harness.db.database;
      final List<Map<String, Object?>> events = await raw.query(
        'sync_event',
        where: 'entity = ? AND entity_id = ?',
        whereArgs: <Object?>['fitness_goal', '$id'],
        orderBy: 'id ASC',
      );
      expect(events.last['operation'], SyncOperation.update.name);
    });

    test('deleting a goal soft-deletes the row and records a DELETE event',
        () async {
      final DateTime now = DateTime.now();
      final int id = await harness.goals.insert(
        FitnessGoal(
          userId: 'u-1',
          title: 'Muscle Building',
          goalType: GoalType.muscleBuilding,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await harness.goals.delete(id);

      expect(await harness.goals.getById(id), isNull);

      final raw = await harness.db.database;
      final List<Map<String, Object?>> events = await raw.query(
        'sync_event',
        where: 'entity = ? AND entity_id = ?',
        whereArgs: <Object?>['fitness_goal', '$id'],
      );
      expect(events.last['operation'], SyncOperation.delete.name);
    });

    test('goal progress shows current, target, percent, remaining and streak',
        () async {
      final DateTime now = DateTime.now();
      for (int d = 0; d < 2; d++) {
        await insertWorkout(now, d);
      }
      await harness.streaks.upsert(
        Streak(
          userId: 'u-1',
          streakType: StreakType.workout,
          currentStreak: 2,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await harness.weightLog.insert(
        WeightLog(
          userId: 'u-1',
          weightKg: 75,
          loggedAt: dayOf(now, 1),
          createdAt: now,
        ),
      );
      await harness.weightLog.insert(
        WeightLog(
          userId: 'u-1',
          weightKg: 74,
          loggedAt: dayOf(now),
          createdAt: now,
        ),
      );
      await harness.goals.insert(
        FitnessGoal(
          userId: 'u-1',
          title: 'Weight Loss',
          goalType: GoalType.weightLoss,
          targetValue: 70,
          targetDate: dayOf(now, 30),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final List<GoalProgress> progress =
          await harness.analytics.loadGoalProgress('u-1');

      final GoalProgress workout = progress.firstWhere(
        (GoalProgress g) => g.kind == GoalKind.workout,
      );
      expect(workout.current, 2);
      expect(workout.target, 4);
      expect(workout.percent.round(), 50);
      expect(workout.remaining, closeTo(2, 0.0001));
      expect(workout.streak, 2);

      final GoalProgress weight = progress.firstWhere(
        (GoalProgress g) => g.kind == GoalKind.weight,
      );
      expect(weight.current, 74);
      expect(weight.target, 70);
      expect(weight.hasTarget, isTrue);
      expect(weight.streak, 2);
      expect(weight.remaining, 4);
      // Weight loss is directional: from 75 down to 70 -> 20% of the way.
      expect(weight.percent.round(), 20);
    });

    test('progress is computed offline from local records only', () async {
      final DateTime now = DateTime.now();
      await insertWorkout(now, 0);
      await harness.waterLog.insert(
        WaterLog(
          userId: 'u-1',
          amountMl: 2500,
          loggedAt: dayOf(now),
          createdAt: now,
        ),
      );
      await harness.streaks.upsert(
        Streak(
          userId: 'u-1',
          streakType: StreakType.water,
          currentStreak: 3,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final List<GoalProgress> progress =
          await harness.analytics.loadGoalProgress('u-1');

      final GoalProgress water = progress.firstWhere(
        (GoalProgress g) => g.kind == GoalKind.water,
      );
      expect(water.current, 2500);
      expect(water.streak, 3);
      expect(
        progress.firstWhere((GoalProgress g) => g.kind == GoalKind.sleep).streak,
        0,
      );
    });

    test('a reached goal reports 100% and remaining zero', () async {
      final DateTime now = DateTime.now();
      for (int d = 0; d < 5; d++) {
        await insertWorkout(now, d);
      }

      final List<GoalProgress> progress =
          await harness.analytics.loadGoalProgress('u-1');

      final GoalProgress workout = progress.firstWhere(
        (GoalProgress g) => g.kind == GoalKind.workout,
      );
      expect(workout.percent.round(), 100);
      expect(workout.remaining, 0);
      expect(workout.fraction, 1);
    });

    test('user goal provider reflects the user-owned goals', () async {
      final DateTime now = DateTime.now();
      final ProviderContainer container = signedInContainer(
        extraOverrides: <Override>[
          fitnessGoalRepositoryProvider.overrideWithValue(harness.goals),
        ],
      );

      expect(await container.read(userGoalsProvider.future), isEmpty);

      await harness.goals.insert(
        FitnessGoal(
          userId: 'u-1',
          title: 'Weight Loss',
          goalType: GoalType.weightLoss,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final List<FitnessGoal> mine =
          await container.read(userGoalsProvider.future);
      expect(mine, hasLength(1));
      expect(mine.single.goalType, GoalType.weightLoss);

      await harness.goals.delete(mine.single.id!);
      expect(await container.read(userGoalsProvider.future), isEmpty);
    });

    test('remote apply updates a goal without creating a loop event',
        () async {
      final DateTime now = DateTime.now();
      final int id = await harness.goals.insert(
        FitnessGoal(
          userId: 'u-1',
          title: 'Weight Loss',
          goalType: GoalType.weightLoss,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final raw = await harness.db.database;
      final String uuid = (await raw.query(
        'fitness_goal',
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      ))
          .single['uuid'] as String;

      await applyRemoteUpdate(uuid);

      final FitnessGoal? loaded = await harness.goals.getById(id);
      expect(loaded!.targetValue, 80);

      final List<Map<String, Object?>> events = await raw.query(
        'sync_event',
        where: 'entity = ? AND entity_id = ?',
        whereArgs: <Object?>['fitness_goal', '$id'],
      );
      // Only the original CREATE event; the remote apply enqueued nothing.
      expect(events, hasLength(1));
      expect(events.single['operation'], SyncOperation.create.name);
    });

    test('user isolation keeps events scoped to the owning user', () async {
      final DateTime now = DateTime.now();
      final int a = await harness.goals.insert(
        FitnessGoal(
          userId: 'u-1',
          title: 'Weight Loss',
          goalType: GoalType.weightLoss,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final int b = await harness.goals.insert(
        FitnessGoal(
          userId: 'u-2',
          title: 'General Fitness',
          goalType: GoalType.generalFitness,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final raw = await harness.db.database;
      final List<Map<String, Object?>> aEvents = await raw.query(
        'sync_event',
        where: 'entity = ? AND entity_id = ?',
        whereArgs: <Object?>['fitness_goal', '$a'],
      );
      final List<Map<String, Object?>> bEvents = await raw.query(
        'sync_event',
        where: 'entity = ? AND entity_id = ?',
        whereArgs: <Object?>['fitness_goal', '$b'],
      );
      expect(aEvents.single['user_id'], 'u-1');
      expect(bEvents.single['user_id'], 'u-2');
    });
  });
}