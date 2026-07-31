import 'package:logging/logging.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/entities/daily_progress.dart';
import '../../domain/entities/streak.dart';
import '../../domain/entities/workout_completion.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/repositories/achievement_repository.dart';
import '../../domain/repositories/daily_progress_repository.dart';
import '../../domain/repositories/exercise_history_repository.dart';
import '../../domain/repositories/streak_repository.dart';
import '../../domain/repositories/workout_history_repository.dart';
import '../../domain/repositories/workout_session_repository.dart';

/// SQLite backed session lifecycle: start + complete with all side-effects.
class WorkoutSessionRepositoryImpl implements WorkoutSessionRepository {
  WorkoutSessionRepositoryImpl({
    required WorkoutHistoryRepository workoutHistoryRepository,
    required ExerciseHistoryRepository exerciseHistoryRepository,
    required DailyProgressRepository dailyProgressRepository,
    required StreakRepository streakRepository,
    required AchievementRepository achievementRepository,
    Logger? logger,
  }) : _workoutHistoryRepository = workoutHistoryRepository,
       _exerciseHistoryRepository = exerciseHistoryRepository,
       _dailyProgressRepository = dailyProgressRepository,
       _streakRepository = streakRepository,
       _achievementRepository = achievementRepository,
       _logger = logger ?? Logger('WorkoutSessionRepository');

  final WorkoutHistoryRepository _workoutHistoryRepository;
  final ExerciseHistoryRepository _exerciseHistoryRepository;
  final DailyProgressRepository _dailyProgressRepository;
  final StreakRepository _streakRepository;
  final AchievementRepository _achievementRepository;
  final Logger _logger;

  @override
  Future<int> startSession({
    required String userId,
    required int workoutId,
  }) async {
    final DateTime now = DateTime.now();
    return _workoutHistoryRepository.insert(
      WorkoutHistory(
        userId: userId,
        workoutId: workoutId,
        startedAt: now,
        isCompleted: false,
        createdAt: now,
      ),
    );
  }

  @override
  Future<WorkoutCompletion> completeSession({
    required int historyId,
    required int durationMinutes,
    required double caloriesBurned,
  }) async {
    final WorkoutHistory? history = await _workoutHistoryRepository.getById(
      historyId,
    );
    if (history == null) {
      throw StateError('Workout history $historyId does not exist');
    }

    final DateTime now = DateTime.now();
    await _workoutHistoryRepository.update(
      history.copyWith(
        endedAt: now,
        durationMinutes: durationMinutes,
        caloriesBurn: caloriesBurned,
        isCompleted: true,
      ),
    );

    final int exercisesCompleted = await _countExercises(historyId);
    final int totalCompleted = await _workoutHistoryRepository.countCompleted(
      history.userId,
    );
    final double totalCalories =
        await _workoutHistoryRepository.getTotalCaloriesBurned(history.userId);

    await _updateDailyProgress(history.userId, durationMinutes, caloriesBurned);
    final Streak streak = await _updateWorkoutStreak(history.userId);

    final List<Achievement> unlocked = await _unlockAchievements(
      userId: history.userId,
      totalCompleted: totalCompleted,
      totalCalories: totalCalories,
      currentStreak: streak.currentStreak,
    );

    return WorkoutCompletion(
      historyId: historyId,
      durationMinutes: durationMinutes,
      caloriesBurned: caloriesBurned,
      exercisesCompleted: exercisesCompleted,
      totalExercises: 0,
      completedAt: now,
      newAchievements: unlocked,
    );
  }

  Future<int> _countExercises(int historyId) async {
    final List<dynamic> rows = await _exerciseHistoryRepository
        .getByWorkoutHistory(historyId);
    return rows.length;
  }

  Future<void> _updateDailyProgress(
    String userId,
    int durationMinutes,
    double caloriesBurned,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DailyProgress? current = await _dailyProgressRepository
        .getByUserAndDate(userId, today);

    if (current == null) {
      await _dailyProgressRepository.upsert(
        DailyProgress(
          userId: userId,
          progressDate: today,
          caloriesBurned: caloriesBurned,
          workoutMinutes: durationMinutes,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }

    await _dailyProgressRepository.upsert(
      current.copyWith(
        caloriesBurned: current.caloriesBurned + caloriesBurned,
        workoutMinutes: current.workoutMinutes + durationMinutes,
        updatedAt: now,
      ),
    );
  }

  Future<Streak> _updateWorkoutStreak(String userId) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final Streak? existing = await _streakRepository.getByUserAndType(
      userId,
      StreakType.workout.name,
    );

    if (existing == null) {
      final Streak streak = Streak(
        userId: userId,
        streakType: StreakType.workout,
        currentStreak: 1,
        longestStreak: 1,
        lastActiveDate: today,
        bestDate: today,
        createdAt: now,
        updatedAt: now,
      );
      await _streakRepository.upsert(streak);
      return streak;
    }

    final DateTime? last = existing.lastActiveDate;
    final DateTime? lastDay = last == null
        ? null
        : DateTime(last.year, last.month, last.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    int current = existing.currentStreak;
    int longest = existing.longestStreak;

    if (lastDay == today) {
      // Already credited today; keep the run.
    } else if (lastDay == yesterday) {
      current += 1;
      if (current > longest) longest = current;
    } else {
      current = 1;
    }

    final Streak updated = existing.copyWith(
      currentStreak: current,
      longestStreak: longest,
      lastActiveDate: today,
      bestDate: longest > existing.longestStreak ? today : existing.bestDate,
      updatedAt: now,
    );
    await _streakRepository.upsert(updated);
    return updated;
  }

  Future<List<Achievement>> _unlockAchievements({
    required String userId,
    required int totalCompleted,
    required double totalCalories,
    required int currentStreak,
  }) async {
    final DateTime now = DateTime.now();
    final List<Achievement> existing = await _achievementRepository.getByUserId(
      userId,
    );
    final Set<String> owned = existing
        .map((Achievement a) => a.achievementType ?? '')
        .toSet();

    final List<Achievement> candidates = <Achievement>[
      if (totalCompleted >= 1)
        Achievement(
          userId: userId,
          name: 'First Workout',
          description: 'Complete your very first workout session.',
          achievementType: 'first_workout',
          icon: 'emoji_events',
          isUnlocked: true,
          unlockedAt: now,
          createdAt: now,
        ),
      if (totalCompleted >= 10)
        Achievement(
          userId: userId,
          name: 'Workout Warrior',
          description: 'Complete 10 workout sessions.',
          achievementType: 'workout_count_10',
          icon: 'military_tech',
          isUnlocked: true,
          unlockedAt: now,
          createdAt: now,
        ),
      if (totalCompleted >= 50)
        Achievement(
          userId: userId,
          name: 'Fitness Freak',
          description: 'Complete 50 workout sessions.',
          achievementType: 'workout_count_50',
          icon: 'local_fire_department',
          isUnlocked: true,
          unlockedAt: now,
          createdAt: now,
        ),
      if (totalCalories >= 500)
        Achievement(
          userId: userId,
          name: 'Calorie Crusher',
          description: 'Burn 500 kcal through workouts.',
          achievementType: 'calories_500',
          icon: 'bolt',
          isUnlocked: true,
          unlockedAt: now,
          createdAt: now,
        ),
      if (totalCalories >= 2000)
        Achievement(
          userId: userId,
          name: 'Calorie King',
          description: 'Burn 2000 kcal through workouts.',
          achievementType: 'calories_2000',
          icon: 'whatshot',
          isUnlocked: true,
          unlockedAt: now,
          createdAt: now,
        ),
      if (currentStreak >= 7)
        Achievement(
          userId: userId,
          name: 'Weekly Warrior',
          description: 'Work out for 7 days in a row.',
          achievementType: 'streak_7',
          icon: 'calendar_month',
          isUnlocked: true,
          unlockedAt: now,
          createdAt: now,
        ),
      if (currentStreak >= 30)
        Achievement(
          userId: userId,
          name: 'Monthly Monster',
          description: 'Work out for 30 days in a row.',
          achievementType: 'streak_30',
          icon: 'workspace_premium',
          isUnlocked: true,
          unlockedAt: now,
          createdAt: now,
        ),
    ];

    final List<Achievement> unlocked = <Achievement>[];
    for (final Achievement achievement in candidates) {
      if (owned.contains(achievement.achievementType)) continue;
      await _achievementRepository.insert(achievement);
      unlocked.add(achievement);
    }
    return unlocked;
  }
}
