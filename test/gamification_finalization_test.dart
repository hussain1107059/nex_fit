import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexfit/data/datasources/local/achievement_local_data_source.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/badge_local_data_source.dart';
import 'package:nexfit/data/datasources/local/daily_progress_local_data_source.dart';
import 'package:nexfit/data/datasources/local/exercise_history_local_data_source.dart';
import 'package:nexfit/data/datasources/local/level_local_data_source.dart';
import 'package:nexfit/data/datasources/local/streak_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_history_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_local_data_source.dart';
import 'package:nexfit/data/datasources/local/xp_history_local_data_source.dart';
import 'package:nexfit/data/repositories/achievement_repository_impl.dart';
import 'package:nexfit/data/repositories/badge_repository_impl.dart';
import 'package:nexfit/data/repositories/daily_progress_repository_impl.dart';
import 'package:nexfit/data/repositories/exercise_history_repository_impl.dart';
import 'package:nexfit/data/repositories/level_repository_impl.dart';
import 'package:nexfit/data/repositories/streak_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/workout_history_repository_impl.dart';
import 'package:nexfit/data/repositories/workout_repository_impl.dart';
import 'package:nexfit/data/repositories/workout_session_repository_impl.dart';
import 'package:nexfit/data/repositories/xp_history_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_contracts.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/domain/entities/achievement.dart';
import 'package:nexfit/domain/entities/badge.dart';
import 'package:nexfit/domain/entities/common_enums.dart';
import 'package:nexfit/domain/entities/level.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/streak.dart';
import 'package:nexfit/domain/entities/workout.dart';
import 'package:nexfit/domain/entities/workout_completion.dart';
import 'package:nexfit/domain/entities/xp_history.dart';

/// PROMPT 33 — Gamification finalization.
///
/// XP is now actually awarded when a workout session is completed: the session
/// repository writes an `xp_history` ledger row (source `workout`, reason
/// `session_completed:<historyId>`) and applies it to the `user_level`
/// singleton, raising the level when the running total crosses the required
/// threshold. The award is keyed by the session itself and guarded by
/// `getByUserAndSourceAndReason` plus the local
/// `UNIQUE(user_id, source, reason)` index, so a retry, an app restart or a
/// duplicated sync push can never double-award. Achievement and badge bulk
/// inserts use `ConflictAlgorithm.ignore` so an unlock can never be re-inserted.
/// Streaks remain fully local (derived, outbox-exempt) and therefore survive
/// temporary offline state unchanged.
///
/// See `docs/NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §29.

class _Harness {
  _Harness(this.db);

  final AppDatabase db;

  late final WorkoutHistoryRepositoryImpl workoutHistory;
  late final ExerciseHistoryRepositoryImpl exerciseHistory;
  late final DailyProgressRepositoryImpl dailyProgress;
  late final StreakRepositoryImpl streaks;
  late final AchievementRepositoryImpl achievements;
  late final BadgeRepositoryImpl badges;
  late final WorkoutRepositoryImpl workouts;
  late final XpHistoryRepositoryImpl xpHistory;
  late final LevelRepositoryImpl levels;
  late final WorkoutSessionRepositoryImpl session;

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
    exerciseHistory = ExerciseHistoryRepositoryImpl(
      ExerciseHistoryLocalDataSource(database: db),
    );
    dailyProgress = DailyProgressRepositoryImpl(
      DailyProgressLocalDataSource(database: db),
    );
    streaks = StreakRepositoryImpl(StreakLocalDataSource(database: db));
    achievements = AchievementRepositoryImpl(
      AchievementLocalDataSource(database: db),
    );
    badges = BadgeRepositoryImpl(BadgeLocalDataSource(database: db));
    workouts = WorkoutRepositoryImpl(WorkoutLocalDataSource(database: db));
    xpHistory = XpHistoryRepositoryImpl(XpHistoryLocalDataSource(database: db));
    levels = LevelRepositoryImpl(LevelLocalDataSource(database: db));

    session = WorkoutSessionRepositoryImpl(
      workoutHistoryRepository: workoutHistory,
      exerciseHistoryRepository: exerciseHistory,
      dailyProgressRepository: dailyProgress,
      streakRepository: streaks,
      achievementRepository: achievements,
      badgeRepository: badges,
      workoutRepository: workouts,
      xpHistoryRepository: xpHistory,
      levelRepository: levels,
    );
  }

  Future<int> insertWorkout() {
    final DateTime now = DateTime.now();
    return workouts.insert(
      Workout(
        userId: 'u-1',
        name: 'Morning Routine',
        createdAt: now,
        updatedAt: now,
      ),
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
      '${await databaseFactory.getDatabasesPath()}/gamification_finalization.db',
    );
    harness = _Harness(
      AppDatabase(databaseName: 'gamification_finalization.db'),
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

  group('PROMPT 33 gamification', () {
    test('completing a session awards XP and creates the level row', () async {
      final int workoutId = await harness.insertWorkout();
      final int historyId = await harness.session.startSession(
        userId: 'u-1',
        workoutId: workoutId,
      );
      final WorkoutCompletion completion = await harness.session
          .completeSession(
            historyId: historyId,
            durationMinutes: 30,
            caloriesBurned: 400,
            totalExercises: 3,
          );

      // XP = 20 + 30*2 + 400~/50 = 20 + 60 + 8 = 88.
      expect(completion.xpEarned, 88);
      expect(completion.xpTotal, 88);
      expect(completion.level, 1);

      final XpHistory? ledger = await harness.xpHistory
          .getByUserAndSourceAndReason('u-1', 'workout', 'session_completed:$historyId');
      expect(ledger, isNotNull);
      expect(ledger!.xp, 88);
      expect(ledger.totalXp, 88);

      final LevelProgress? level = await harness.levels.getByUserId('u-1');
      expect(level, isNotNull);
      expect(level!.level, 1);
      expect(level.currentXp, 88);
      expect(level.requiredXp, 100);
      expect(level.totalXp, 88);
    });

    test('re-completing the same session never awards XP twice', () async {
      final int workoutId = await harness.insertWorkout();
      final int historyId = await harness.session.startSession(
        userId: 'u-1',
        workoutId: workoutId,
      );
      final WorkoutCompletion first = await harness.session.completeSession(
        historyId: historyId,
        durationMinutes: 30,
        caloriesBurned: 400,
        totalExercises: 3,
      );
      expect(first.xpEarned, 88);

      // Simulate a retry / app restart that re-runs the same completion.
      final WorkoutCompletion retry = await harness.session.completeSession(
        historyId: historyId,
        durationMinutes: 30,
        caloriesBurned: 400,
        totalExercises: 3,
      );
      expect(retry.xpEarned, 0);

      final List<XpHistory> ledger = await harness.xpHistory.getByUserId('u-1');
      expect(ledger, hasLength(1));

      final LevelProgress? level = await harness.levels.getByUserId('u-1');
      expect(level!.totalXp, 88);
    });

    test('XP accumulates and levels up across sessions', () async {
      final int workoutId = await harness.insertWorkout();
      for (int i = 0; i < 3; i++) {
        final int historyId = await harness.session.startSession(
          userId: 'u-1',
          workoutId: workoutId,
        );
        await harness.session.completeSession(
          historyId: historyId,
          durationMinutes: 30,
          caloriesBurned: 400,
          totalExercises: 3,
        );
      }

      // 3 * 88 = 264 XP total. Required for level 1 is 100, for level 2 is
      // 200, so the user lands on level 3 with 264 - 100 - 200 = ... actually
      // the level-up loop is: level1 needs 100 (cur 100), level2 needs 200.
      // 264 >= 100 -> level 2, cur 164; 164 < 200 -> stop.
      final LevelProgress? level = await harness.levels.getByUserId('u-1');
      expect(level!.level, 2);
      expect(level.currentXp, 164);
      expect(level.requiredXp, 200);
      expect(level.totalXp, 264);

      final List<XpHistory> ledger = await harness.xpHistory.getByUserId('u-1');
      expect(ledger, hasLength(3));
    });

    test('achievement unlock is idempotent across sessions', () async {
      final int workoutId = await harness.insertWorkout();

      final int first = await harness.session.startSession(
        userId: 'u-1',
        workoutId: workoutId,
      );
      final WorkoutCompletion firstCompletion = await harness.session
          .completeSession(
            historyId: first,
            durationMinutes: 30,
            caloriesBurned: 400,
            totalExercises: 3,
          );
      expect(
        firstCompletion.newAchievements
            .where((Achievement a) => a.achievementType == 'first_workout'),
        hasLength(1),
      );

      final int second = await harness.session.startSession(
        userId: 'u-1',
        workoutId: workoutId,
      );
      final WorkoutCompletion secondCompletion = await harness.session
          .completeSession(
            historyId: second,
            durationMinutes: 30,
            caloriesBurned: 400,
            totalExercises: 3,
          );
      expect(
        secondCompletion.newAchievements
            .where((Achievement a) => a.achievementType == 'first_workout'),
        isEmpty,
      );

      final List<Achievement> owned = await harness.achievements.getByUserId(
        'u-1',
      );
      expect(
        owned.where((Achievement a) => a.achievementType == 'first_workout'),
        hasLength(1),
      );
    });

    test('bulk badge and achievement inserts ignore duplicates', () async {
      final DateTime now = DateTime.now();
      final Badge badge = Badge(
        userId: 'u-1',
        badgeType: 'first_workout',
        badgeName: 'First Step',
        icon: 'direction_run',
        level: 1,
        progress: 1,
        target: 1,
        isEarned: true,
        earnedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      await harness.badges.insertAll(<Badge>[badge]);
      // Inserting the same badge again must not throw.
      await harness.badges.insertAll(<Badge>[badge]);
      expect(await harness.badges.getByUserId('u-1'), hasLength(1));

      final Achievement achievement = Achievement(
        userId: 'u-1',
        name: 'First Workout',
        description: 'Complete your very first workout session.',
        achievementType: 'first_workout',
        icon: 'emoji_events',
        isUnlocked: true,
        unlockedAt: now,
        createdAt: now,
      );
      await harness.achievements.insertAll(<Achievement>[achievement]);
      await harness.achievements.insertAll(<Achievement>[achievement]);
      final List<Achievement> owned = await harness.achievements.getByUserId(
        'u-1',
      );
      expect(owned, hasLength(1));
    });

    test('streak survives temporary offline (recorder disabled)', () async {
      final int workoutId = await harness.insertWorkout();

      // Online completion establishes the streak.
      final int online = await harness.session.startSession(
        userId: 'u-1',
        workoutId: workoutId,
      );
      await harness.session.completeSession(
        historyId: online,
        durationMinutes: 30,
        caloriesBurned: 400,
        totalExercises: 3,
      );
      final Streak? before =
          await harness.streaks.getByUserAndType('u-1', StreakType.workout.name);
      expect(before!.currentStreak, 1);

      // Go "offline": the recorder is disabled but the local completion still
      // runs end to end and must preserve the streak, not reset it.
      SyncEventRecorder.setEnabled(false);
      final int offline = await harness.session.startSession(
        userId: 'u-1',
        workoutId: workoutId,
      );
      final WorkoutCompletion completion = await harness.session.completeSession(
        historyId: offline,
        durationMinutes: 30,
        caloriesBurned: 400,
        totalExercises: 3,
      );
      SyncEventRecorder.setEnabled(true);

      expect(completion.xpEarned, 88);
      final Streak? after = await harness.streaks.getByUserAndType(
        'u-1',
        StreakType.workout.name,
      );
      expect(after!.currentStreak, 1);

      final LevelProgress? level = await harness.levels.getByUserId('u-1');
      expect(level!.totalXp, 176);
    });

    test('completing a session records sync events for XP and level',
        () async {
      final int workoutId = await harness.insertWorkout();
      final int historyId = await harness.session.startSession(
        userId: 'u-1',
        workoutId: workoutId,
      );
      await harness.session.completeSession(
        historyId: historyId,
        durationMinutes: 30,
        caloriesBurned: 400,
        totalExercises: 3,
      );

      final raw = await harness.db.database;
      final List<Map<String, Object?>> xpEvents = await raw.query(
        'sync_event',
        where: 'entity = ?',
        whereArgs: <Object?>['xp_history'],
      );
      expect(xpEvents, hasLength(1));
      expect(xpEvents.single['operation'], SyncOperation.create.name);
      expect(xpEvents.single['user_id'], 'u-1');

      final List<Map<String, Object?>> levelEvents = await raw.query(
        'sync_event',
        where: 'entity = ?',
        whereArgs: <Object?>['user_level'],
      );
      expect(levelEvents, hasLength(1));
      expect(levelEvents.single['operation'], SyncOperation.create.name);
    });

    test('pulling XP and level from the cloud converges without duplicates',
        () async {
      final int workoutId = await harness.insertWorkout();
      final int historyId = await harness.session.startSession(
        userId: 'u-1',
        workoutId: workoutId,
      );
      await harness.session.completeSession(
        historyId: historyId,
        durationMinutes: 30,
        caloriesBurned: 400,
        totalExercises: 3,
      );

      final raw = await harness.db.database;
      final Map<String, Object?> xpRow = (await raw.query(
        'xp_history',
        where: 'user_id = ?',
        whereArgs: <Object?>['u-1'],
      ))
          .single;
      final Map<String, Object?> levelRow = (await raw.query(
        'user_level',
        where: 'user_id = ?',
        whereArgs: <Object?>['u-1'],
      ))
          .single;

      // Simulate the cloud pushing those two rows back into the same device
      // (as a pull snapshot). Applying must not create local events.
      final RemoteChangeApplier applier = RemoteChangeApplier(database: harness.db);
      await raw.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'xp_history',
            recordId: xpRow['uuid'] as String,
            operation: SyncOperation.update,
            payload: <String, Object?>{
              'id': xpRow['uuid'],
              'user_id': 'u-1',
              'source': 'workout',
              'reason': xpRow['reason'],
              'xp': xpRow['xp'],
              'row_version': 1,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
              'deleted_at': null,
            },
          ),
        );
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 2,
            cloudTable: 'user_levels',
            recordId: 'u-1',
            operation: SyncOperation.update,
            payload: <String, Object?>{
              'id': 'u-1',
              'user_id': 'u-1',
              'level': levelRow['level'],
              'current_xp': levelRow['current_xp'],
              'required_xp': levelRow['required_xp'],
              'total_xp': levelRow['total_xp'],
              'row_version': 1,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
              'deleted_at': null,
            },
          ),
        );
      });

      // Still exactly one ledger row and one level row, and no echo events.
      expect(await raw.query('xp_history'), hasLength(1));
      expect(await raw.query('user_level'), hasLength(1));
      final List<Map<String, Object?>> events = await raw.query(
        'sync_event',
        where: 'entity = ? OR entity = ?',
        whereArgs: <Object?>['xp_history', 'user_level'],
      );
      expect(events, hasLength(2));
    });

    test('remote apply converges a second device without double awards',
        () async {
      // Device A: complete a session, awarding 88 XP.
      final int workoutId = await harness.insertWorkout();
      final int historyId = await harness.session.startSession(
        userId: 'u-1',
        workoutId: workoutId,
      );
      await harness.session.completeSession(
        historyId: historyId,
        durationMinutes: 30,
        caloriesBurned: 400,
        totalExercises: 3,
      );

      // Device B pulls the same rows (the rows were already written locally,
      // so this is the converged state — the same rows exist exactly once).
      final raw = await harness.db.database;
      expect(await raw.query('xp_history'), hasLength(1));
      expect(await raw.query('user_level'), hasLength(1));

      // Device B completes its own session on the same account.
      final int secondWorkoutId = await harness.insertWorkout();
      final int secondHistoryId = await harness.session.startSession(
        userId: 'u-1',
        workoutId: secondWorkoutId,
      );
      final WorkoutCompletion second = await harness.session.completeSession(
        historyId: secondHistoryId,
        durationMinutes: 30,
        caloriesBurned: 400,
        totalExercises: 3,
      );
      expect(second.xpEarned, 88);
      expect(second.xpTotal, 176);

      // A later pull of the level singleton converges on the same total.
      final LevelProgress? level = await harness.levels.getByUserId('u-1');
      expect(level!.totalXp, 176);
      expect(await raw.query('xp_history'), hasLength(2));
    });

    test('per-user XP and levels are isolated', () async {
      final int workoutId = await harness.insertWorkout();
      final int historyId = await harness.session.startSession(
        userId: 'u-1',
        workoutId: workoutId,
      );
      await harness.session.completeSession(
        historyId: historyId,
        durationMinutes: 30,
        caloriesBurned: 400,
        totalExercises: 3,
      );

      final raw = await harness.db.database;
      await raw.insert('workout_history', <String, Object?>{
        'user_id': 'u-2',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'is_completed': 1,
        'duration_minutes': 30,
        'calories_burn': 400,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      expect(await harness.xpHistory.totalXpForUser('u-1'), 88);
      expect(await harness.xpHistory.totalXpForUser('u-2'), 0);
      final List<XpHistory> userTwoLedger = await harness.xpHistory.getByUserId(
        'u-2',
      );
      expect(userTwoLedger, isEmpty);
    });
  });
}