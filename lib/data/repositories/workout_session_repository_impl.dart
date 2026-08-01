import '../../domain/entities/achievement.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/entities/daily_progress.dart';
import '../../domain/entities/streak.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_completion.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/repositories/achievement_repository.dart';
import '../../domain/repositories/badge_repository.dart';
import '../../domain/repositories/daily_progress_repository.dart';
import '../../domain/repositories/exercise_history_repository.dart';
import '../../domain/repositories/streak_repository.dart';
import '../../domain/repositories/workout_history_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/repositories/workout_session_repository.dart';

/// Metric a badge tracks.
enum _BadgeMetric { workouts, calories, streak }

class _BadgeDefinition {
  const _BadgeDefinition({
    required this.type,
    required this.name,
    required this.icon,
    required this.target,
    required this.metric,
  });

  final String type;
  final String name;
  final String icon;
  final double target;
  final _BadgeMetric metric;
}

/// SQLite backed session lifecycle: start + complete with all side-effects.
class WorkoutSessionRepositoryImpl implements WorkoutSessionRepository {
  WorkoutSessionRepositoryImpl({
    required this.workoutHistoryRepository,
    required this.exerciseHistoryRepository,
    required this.dailyProgressRepository,
    required this.streakRepository,
    required this.achievementRepository,
    required this.badgeRepository,
    required this.workoutRepository,
  });

  static const List<_BadgeDefinition> _badgeDefinitions =
      <_BadgeDefinition>[
        _BadgeDefinition(
          type: 'first_workout',
          name: 'First Step',
          icon: 'direction_run',
          target: 1,
          metric: _BadgeMetric.workouts,
        ),
        _BadgeDefinition(
          type: 'workouts_5',
          name: 'Consistent',
          icon: 'repeat',
          target: 5,
          metric: _BadgeMetric.workouts,
        ),
        _BadgeDefinition(
          type: 'workouts_15',
          name: 'Dedicated',
          icon: 'stars',
          target: 15,
          metric: _BadgeMetric.workouts,
        ),
        _BadgeDefinition(
          type: 'workouts_50',
          name: 'Iron Warrior',
          icon: 'military_tech',
          target: 50,
          metric: _BadgeMetric.workouts,
        ),
        _BadgeDefinition(
          type: 'calories_1000',
          name: 'Calorie Burner',
          icon: 'local_fire_department',
          target: 1000,
          metric: _BadgeMetric.calories,
        ),
        _BadgeDefinition(
          type: 'calories_5000',
          name: 'Calorie Crusher',
          icon: 'whatshot',
          target: 5000,
          metric: _BadgeMetric.calories,
        ),
        _BadgeDefinition(
          type: 'streak_7',
          name: 'Week Warrior',
          icon: 'calendar_month',
          target: 7,
          metric: _BadgeMetric.streak,
        ),
        _BadgeDefinition(
          type: 'streak_30',
          name: 'Month Master',
          icon: 'workspace_premium',
          target: 30,
          metric: _BadgeMetric.streak,
        ),
      ];

  final WorkoutHistoryRepository workoutHistoryRepository;
  final ExerciseHistoryRepository exerciseHistoryRepository;
  final DailyProgressRepository dailyProgressRepository;
  final StreakRepository streakRepository;
  final AchievementRepository achievementRepository;
  final BadgeRepository badgeRepository;
  final WorkoutRepository workoutRepository;

  @override
  Future<int> startSession({
    required String userId,
    required int workoutId,
  }) async {
    final DateTime now = DateTime.now();
    return workoutHistoryRepository.insert(
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
    required int totalExercises,
  }) async {
    final WorkoutHistory? history = await workoutHistoryRepository.getById(
      historyId,
    );
    if (history == null) {
      throw StateError('Workout history $historyId does not exist');
    }

    final DateTime now = DateTime.now();
    await workoutHistoryRepository.update(
      history.copyWith(
        endedAt: now,
        durationMinutes: durationMinutes,
        caloriesBurn: caloriesBurned,
        isCompleted: true,
      ),
    );

    final int exercisesCompleted = await _countExercises(historyId);
    final int totalCompleted = await workoutHistoryRepository.countCompleted(
      history.userId,
    );
    final double totalCalories = await workoutHistoryRepository
        .getTotalCaloriesBurned(history.userId);

    await _updateDailyProgress(history.userId, durationMinutes, caloriesBurned);
    final Streak streak = await _updateWorkoutStreak(history.userId);

    final List<Achievement> unlocked = await _unlockAchievements(
      userId: history.userId,
      totalCompleted: totalCompleted,
      totalCalories: totalCalories,
      currentStreak: streak.currentStreak,
    );

    final List<Badge> badges = await _updateBadges(
      userId: history.userId,
      totalCompleted: totalCompleted,
      totalCalories: totalCalories,
      currentStreak: streak.currentStreak,
    );

    final String? workoutName = await _workoutName(history.workoutId);

    return WorkoutCompletion(
      historyId: historyId,
      durationMinutes: durationMinutes,
      caloriesBurned: caloriesBurned,
      exercisesCompleted: exercisesCompleted,
      totalExercises: totalExercises,
      completedAt: now,
      workoutName: workoutName,
      completionPercent: totalExercises == 0
          ? 0
          : (exercisesCompleted / totalExercises) * 100,
      currentStreak: streak.currentStreak,
      newAchievements: unlocked,
      newBadges: badges,
    );
  }

  Future<String?> _workoutName(int? workoutId) async {
    if (workoutId == null) return null;
    final Workout? workout = await workoutRepository.getById(workoutId);
    return workout?.name;
  }

  Future<int> _countExercises(int historyId) async {
    final List<dynamic> rows = await exerciseHistoryRepository
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
    final DailyProgress? current = await dailyProgressRepository
        .getByUserAndDate(userId, today);

    if (current == null) {
      await dailyProgressRepository.upsert(
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

    await dailyProgressRepository.upsert(
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
    final Streak? existing = await streakRepository.getByUserAndType(
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
      await streakRepository.upsert(streak);
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
    await streakRepository.upsert(updated);
    return updated;
  }

  Future<List<Badge>> _updateBadges({
    required String userId,
    required int totalCompleted,
    required double totalCalories,
    required int currentStreak,
  }) async {
    final DateTime now = DateTime.now();
    final List<Badge> newlyEarned = <Badge>[];

    // Load every badge for the user once and index by type, turning the
    // previous N+1 (one SELECT + one write per definition) into a single read
    // plus two batched writes.
    final Map<String, Badge> byType = <String, Badge>{
      for (final Badge badge in await badgeRepository.getByUserId(userId))
        badge.badgeType: badge,
    };

    final List<Badge> toInsert = <Badge>[];
    final List<Badge> toUpdate = <Badge>[];

    for (final _BadgeDefinition definition in _badgeDefinitions) {
      final double progress = switch (definition.metric) {
        _BadgeMetric.workouts => totalCompleted.toDouble(),
        _BadgeMetric.calories => totalCalories,
        _BadgeMetric.streak => currentStreak.toDouble(),
      };
      final double clamped = progress.clamp(0.0, definition.target);
      final bool earned = clamped >= definition.target;
      final Badge? existing = byType[definition.type];

      final Badge badge = Badge(
        id: existing?.id,
        userId: userId,
        badgeType: definition.type,
        badgeName: definition.name,
        icon: definition.icon,
        level: 1,
        progress: clamped,
        target: definition.target,
        isEarned: earned,
        earnedAt: earned ? (existing?.earnedAt ?? now) : existing?.earnedAt,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (existing == null) {
        toInsert.add(badge);
      } else {
        toUpdate.add(badge);
      }

      if (earned && (existing == null || !existing.isEarned)) {
        newlyEarned.add(badge.copyWith(id: null));
      }
    }

    if (toInsert.isNotEmpty) {
      await badgeRepository.insertAll(toInsert);
    }
    if (toUpdate.isNotEmpty) {
      await badgeRepository.updateAll(toUpdate);
    }

    return newlyEarned;
  }

  Future<List<Achievement>> _unlockAchievements({
    required String userId,
    required int totalCompleted,
    required double totalCalories,
    required int currentStreak,
  }) async {
    final DateTime now = DateTime.now();
    final List<Achievement> existing = await achievementRepository.getByUserId(
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
    final List<Achievement> toInsert = <Achievement>[
      for (final Achievement achievement in candidates)
        if (!owned.contains(achievement.achievementType)) achievement,
    ];
    if (toInsert.isNotEmpty) {
      await achievementRepository.insertAll(toInsert);
      unlocked.addAll(toInsert);
    }
    return unlocked;
  }
}
