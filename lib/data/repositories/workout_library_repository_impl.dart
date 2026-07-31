import '../../domain/entities/common_enums.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_category.dart';
import '../../domain/entities/workout_detail.dart';
import '../../domain/entities/workout_exercise_detail.dart';
import '../../domain/entities/workout_filter.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/entities/workout_library.dart';
import '../../domain/repositories/exercise_history_repository.dart';
import '../../domain/repositories/user_fitness_profile_repository.dart';
import '../../domain/repositories/workout_category_repository.dart';
import '../../domain/repositories/workout_exercise_repository.dart';
import '../../domain/repositories/workout_history_repository.dart';
import '../../domain/repositories/workout_library_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../services/workout_seeder.dart';

/// Aggregates the offline workout library from the low level repositories.
class WorkoutLibraryRepositoryImpl implements WorkoutLibraryRepository {
  WorkoutLibraryRepositoryImpl({
    required this.workoutRepository,
    required this.categoryRepository,
    required this.historyRepository,
    required this.workoutExerciseRepository,
    required this.exerciseHistoryRepository,
    required this.userProfileRepository,
    required this.seeder,
  });

  static const int _collectionLimit = 6;

  final WorkoutRepository workoutRepository;
  final WorkoutCategoryRepository categoryRepository;
  final WorkoutHistoryRepository historyRepository;
  final WorkoutExerciseRepository workoutExerciseRepository;
  final ExerciseHistoryRepository exerciseHistoryRepository;
  final UserFitnessProfileRepository userProfileRepository;
  final WorkoutSeeder seeder;

  @override
  Future<void> ensureSeeded(String userId) => seeder.seedForUser(userId);

  @override
  Future<WorkoutLibraryData> loadLibrary(String userId) async {
    await ensureSeeded(userId);

    final List<WorkoutCategory> categories = await categoryRepository.getAll();
    final List<Workout> workouts = await workoutRepository.getByUserId(userId);

    if (workouts.isEmpty) {
      return const WorkoutLibraryData();
    }

    final List<Workout> favorites = await workoutRepository.getFavorites(
      userId,
    );
    final List<int> popularIds = await historyRepository.getPopularWorkoutIds(
      userId,
      limit: _collectionLimit,
    );
    final List<int> recentIds = await historyRepository.getRecentWorkoutIds(
      userId,
      limit: _collectionLimit,
    );
    final WorkoutHistory? inProgress = await historyRepository.getInProgress(
      userId,
    );

    final Map<int, Workout> byId = <int, Workout>{
      for (final Workout workout in workouts)
        if (workout.id != null) workout.id!: workout,
    };

    final List<Workout> popular = popularIds
        .map((int id) => byId[id])
        .whereType<Workout>()
        .toList();
    final List<Workout> recent = recentIds
        .map((int id) => byId[id])
        .whereType<Workout>()
        .toList();
    final List<Workout> recommended = await _recommendedFor(
      userId,
      workouts,
      categories,
      byId,
    );

    ContinueWorkout? continueWorkout;
    if (inProgress != null && inProgress.workoutId != null) {
      final Workout? workout = byId[inProgress.workoutId];
      if (workout != null) {
        final int completed = await exerciseHistoryRepository
            .getByWorkoutHistory(inProgress.id!)
            .then((List<dynamic> rows) => rows.length);
        final int total = await workoutExerciseRepository
            .getDetailsByWorkout(inProgress.workoutId!)
            .then((List<dynamic> rows) => rows.length);
        continueWorkout = ContinueWorkout(
          workout: workout,
          historyId: inProgress.id!,
          startedAt: inProgress.startedAt,
          completedExercises: completed,
          totalExercises: total,
        );
      }
    }

    return WorkoutLibraryData(
      categories: categories,
      recommended: recommended,
      popular: popular,
      recent: recent,
      continueWorkout: continueWorkout,
      favorites: favorites,
    );
  }

  Future<List<Workout>> _recommendedFor(
    String userId,
    List<Workout> workouts,
    List<WorkoutCategory> categories,
    Map<int, Workout> byId,
  ) async {
    final UserProfile? profile = await userProfileRepository.getById(userId);
    final List<String> slugs = _goalCategorySlugs(profile?.fitnessGoal);

    final Set<int> goalCategoryIds = <int>{};
    for (final WorkoutCategory category in categories) {
      if (slugs.contains(category.slug)) goalCategoryIds.add(category.id!);
    }

    final Map<String, int> slugToId = <String, int>{
      for (final WorkoutCategory category in categories)
        category.slug: category.id!,
    };

    final List<Workout> matched =
        workouts
            .where(
              (Workout workout) =>
                  workout.categoryId != null &&
                  goalCategoryIds.contains(workout.categoryId),
            )
            .toList()
          ..sort((Workout a, Workout b) {
            final int rankA = _categoryRank(a.categoryId!, slugs, slugToId);
            final int rankB = _categoryRank(b.categoryId!, slugs, slugToId);
            final int rank = rankA.compareTo(rankB);
            return rank != 0
                ? rank
                : (b.isFavorite == a.isFavorite ? 0 : (b.isFavorite ? 1 : -1));
          });

    if (matched.isNotEmpty) {
      return matched.take(_collectionLimit).toList();
    }
    return workouts.take(_collectionLimit).toList();
  }

  List<String> _goalCategorySlugs(GoalType? goal) {
    switch (goal) {
      case GoalType.weightLoss:
        return const <String>['fat-loss', 'cardio', 'hiit'];
      case GoalType.muscleBuilding:
        return const <String>[
          'muscle-gain',
          'strength',
          'chest',
          'back',
          'shoulder',
          'arms',
          'legs',
        ];
      case GoalType.maintainWeight:
        return const <String>['full-body', 'cardio', 'beginner'];
      case GoalType.generalFitness:
        return const <String>['full-body', 'beginner', 'stretching', 'yoga'];
      case GoalType.weightGain:
        return const <String>['muscle-gain', 'strength', 'beginner'];
      case GoalType.other:
        return const <String>['full-body', 'beginner', 'home-workout'];
      case null:
        return const <String>['full-body', 'beginner', 'home-workout'];
    }
  }

  int _categoryRank(
    int categoryId,
    List<String> slugs,
    Map<String, int> slugToId,
  ) {
    for (int index = 0; index < slugs.length; index++) {
      if (slugToId[slugs[index]] == categoryId) return index;
    }
    return slugs.length;
  }

  @override
  Future<WorkoutDetail> getDetail(int workoutId) async {
    final Workout? workout = await workoutRepository.getById(workoutId);
    if (workout == null) {
      throw StateError('Workout $workoutId does not exist');
    }

    WorkoutCategory? category;
    if (workout.categoryId != null) {
      category = await categoryRepository.getById(workout.categoryId!);
    }

    final List<WorkoutExerciseDetail> exercises =
        await workoutExerciseRepository.getDetailsByWorkout(workoutId);
    return WorkoutDetail(
      workout: workout,
      category: category,
      exercises: exercises,
    );
  }

  @override
  Future<List<Workout>> search(String userId, WorkoutFilter filter) async {
    final List<Workout> all = await workoutRepository.getByUserId(userId);
    List<Workout> results = all;

    final String query = filter.query.trim().toLowerCase();
    if (query.isNotEmpty) {
      results = results
          .where(
            (Workout workout) => workout.name.toLowerCase().contains(query),
          )
          .toList();
    }

    if (filter.difficulty != null) {
      results = results
          .where((Workout workout) => workout.difficulty == filter.difficulty)
          .toList();
    }

    if (filter.duration != WorkoutDurationFilter.any) {
      results = results.where((Workout workout) {
        final int? duration = workout.durationMinutes;
        return switch (filter.duration) {
          WorkoutDurationFilter.short => duration != null && duration <= 20,
          WorkoutDurationFilter.medium =>
            duration != null && duration > 20 && duration <= 40,
          WorkoutDurationFilter.long => duration != null && duration > 40,
          WorkoutDurationFilter.any => true,
        };
      }).toList();
    }

    if (filter.categorySlug != null && filter.categorySlug!.isNotEmpty) {
      final WorkoutCategory? category = await categoryRepository.getBySlug(
        filter.categorySlug!,
      );
      final int? categoryId = category?.id;
      results = results
          .where(
            (Workout workout) =>
                categoryId != null && workout.categoryId == categoryId,
          )
          .toList();
    }

    if (filter.goal != null && filter.goal!.isNotEmpty) {
      final List<String> slugs = _goalCategorySlugs(
        GoalType.fromName(filter.goal),
      );
      final List<WorkoutCategory> categories = await categoryRepository
          .getAll();
      final Set<int> ids = categories
          .where((WorkoutCategory category) => slugs.contains(category.slug))
          .map((WorkoutCategory category) => category.id!)
          .toSet();
      results = results
          .where(
            (Workout workout) =>
                workout.categoryId != null && ids.contains(workout.categoryId),
          )
          .toList();
    }

    if (filter.equipment != null && filter.equipment!.isNotEmpty) {
      final String equipment = filter.equipment!;
      final List<int> ids = results
          .map((Workout workout) => workout.id!)
          .toList();
      final Map<int, List<WorkoutExerciseDetail>> details =
          await workoutExerciseRepository.getDetailsByWorkouts(ids);
      results = results.where((Workout workout) {
        final List<WorkoutExerciseDetail> exerciseDetails =
            details[workout.id!] ?? const <WorkoutExerciseDetail>[];
        return exerciseDetails.any(
          (WorkoutExerciseDetail detail) =>
              detail.exercise.equipment == equipment,
        );
      }).toList();
    }

    return results;
  }

  @override
  Future<List<Workout>> getByCategory(
    String userId,
    String categorySlug,
  ) async {
    final WorkoutCategory? category = await categoryRepository.getBySlug(
      categorySlug,
    );
    if (category == null) return const <Workout>[];
    return workoutRepository.getByCategoryForUser(userId, category.id!);
  }

  @override
  Future<bool> toggleFavorite(int workoutId) async {
    final Workout? workout = await workoutRepository.getById(workoutId);
    if (workout == null) {
      throw StateError('Workout $workoutId does not exist');
    }
    final bool next = !workout.isFavorite;
    await workoutRepository.setFavorite(workoutId, next);
    return next;
  }
}
