import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/exercise_history.dart';
import '../../domain/entities/workout_completion.dart';
import '../../domain/entities/workout_detail.dart';
import '../../domain/entities/workout_exercise_detail.dart';
import '../../domain/entities/workout_filter.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/entities/workout_library.dart';
import '../../domain/entities/workout.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';

/// Loads and refreshes the workout home aggregate.
class WorkoutLibraryController extends AsyncNotifier<WorkoutLibraryData> {
  @override
  Future<WorkoutLibraryData> build() => _load();

  Future<WorkoutLibraryData> _load() async {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      throw StateError('Workout library requires a signed-in user');
    }
    return ref.watch(workoutLibraryRepositoryProvider).loadLibrary(user.id);
  }

  Future<void> refresh() async {
    state = AsyncValue<WorkoutLibraryData>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }
}

final workoutLibraryControllerProvider =
    AsyncNotifierProvider<WorkoutLibraryController, WorkoutLibraryData>(
      WorkoutLibraryController.new,
    );

/// A single workout enriched with its category and exercises.
final workoutDetailProvider =
    FutureProvider.autoDispose.family<WorkoutDetail, int>((ref, workoutId) {
      return ref.watch(workoutLibraryRepositoryProvider).getDetail(workoutId);
    });

/// Every workout owned by a user.
final workoutAllProvider =
    FutureProvider.autoDispose.family<List<Workout>, String>((ref, userId) {
      return ref.watch(workoutRepositoryProvider).getByUserId(userId);
    });

/// The user's favourite workouts.
final workoutFavoritesProvider =
    FutureProvider.autoDispose.family<List<Workout>, String>((ref, userId) {
      return ref.watch(workoutRepositoryProvider).getFavorites(userId);
    });

/// All workouts inside a category slug for a user.
final workoutCategoryWorkoutsProvider =
    FutureProvider.autoDispose.family<List<Workout>, ({String userId, String slug})>(
      (ref, params) => ref
          .watch(workoutLibraryRepositoryProvider)
          .getByCategory(params.userId, params.slug),
    );

/// Current text in the workout search field.
final workoutSearchQueryProvider = StateProvider<String>((ref) => '');

/// Currently applied workout filters.
final workoutSearchFilterProvider =
    StateProvider<WorkoutFilter>((ref) => const WorkoutFilter());

/// Combined search + filter results.
final workoutSearchResultsProvider =
    FutureProvider.autoDispose<List<Workout>>((ref) async {
      final String query = ref.watch(workoutSearchQueryProvider);
      final WorkoutFilter filter = ref.watch(workoutSearchFilterProvider);
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return const <Workout>[];

      final WorkoutFilter effective = filter.query == query
          ? filter
          : filter.copyWith(query: query);
      if (effective.isEmpty) return const <Workout>[];
      return ref
          .watch(workoutLibraryRepositoryProvider)
          .search(user.id, effective);
    });

/// Toggles the favourite flag of a workout and refreshes the library.
Future<void> toggleWorkoutFavorite(WidgetRef ref, int workoutId) async {
  await ref.read(workoutLibraryRepositoryProvider).toggleFavorite(workoutId);
  ref.invalidate(workoutLibraryControllerProvider);
  ref.invalidate(workoutDetailProvider(workoutId));
}

/// Configures the behaviour of the shared workout list screen.
class WorkoutListArgs extends Equatable {
  const WorkoutListArgs._({
    this.title,
    this.categorySlug,
    this.favoritesOnly = false,
    this.searchMode = false,
  });

  const WorkoutListArgs.search()
      : this._(searchMode: true);

  const WorkoutListArgs.all() : this._();

  const WorkoutListArgs.favorites()
      : this._(favoritesOnly: true);

  const WorkoutListArgs.category(String slug, String name)
      : this._(categorySlug: slug, title: name);

  final String? title;
  final String? categorySlug;
  final bool favoritesOnly;
  final bool searchMode;

  @override
  List<Object?> get props => [title, categorySlug, favoritesOnly, searchMode];
}

/// Completed workout sessions plus the data needed to render them.
class WorkoutHistoryData extends Equatable {
  const WorkoutHistoryData({
    required this.sessions,
    required this.workouts,
    required this.totalCompleted,
    required this.totalCalories,
  });

  final List<WorkoutHistory> sessions;
  final Map<int, Workout> workouts;
  final int totalCompleted;
  final double totalCalories;

  Workout? workoutFor(WorkoutHistory history) {
    final int? workoutId = history.workoutId;
    return workoutId == null ? null : workouts[workoutId];
  }

  @override
  List<Object?> get props => [
        sessions,
        workouts,
        totalCompleted,
        totalCalories,
      ];
}

/// Aggregate loaded for the workout history screen.
final workoutHistoryProvider = FutureProvider.autoDispose<WorkoutHistoryData>(
  (ref) async {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      throw StateError('Workout history requires a signed-in user');
    }

    final List<WorkoutHistory> sessions =
        await ref.watch(workoutHistoryRepositoryProvider).getCompleted(user.id);
    final List<int> ids = sessions
        .map((WorkoutHistory history) => history.workoutId)
        .whereType<int>()
        .toSet()
        .toList();
    final List<Workout> workouts = await ref
        .watch(workoutRepositoryProvider)
        .getByIds(ids);
    final Map<int, Workout> byId = <int, Workout>{
      for (final Workout workout in workouts)
        if (workout.id != null) workout.id!: workout,
    };
    final int totalCompleted =
        await ref.watch(workoutHistoryRepositoryProvider).countCompleted(user.id);
    final double totalCalories = await ref
        .watch(workoutHistoryRepositoryProvider)
        .getTotalCaloriesBurned(user.id);

    return WorkoutHistoryData(
      sessions: sessions,
      workouts: byId,
      totalCompleted: totalCompleted,
      totalCalories: totalCalories,
    );
  },
);

/// Arguments handed to the workout player.
class WorkoutPlayerArgs extends Equatable {
  const WorkoutPlayerArgs({
    required this.workoutId,
    this.historyId,
    this.startedAt,
  });

  final int workoutId;
  final int? historyId;
  final DateTime? startedAt;

  @override
  List<Object?> get props => [workoutId, historyId, startedAt];
}

/// Where the player currently sits inside a session.
enum WorkoutSessionPhase { idle, exercising, resting, completed }

/// Immutable snapshot of an active workout session.
class WorkoutPlayerState extends Equatable {
  const WorkoutPlayerState({
    required this.detail,
    required this.historyId,
    this.phase = WorkoutSessionPhase.idle,
    this.currentIndex = 0,
    this.currentRemainingSeconds = 0,
    this.elapsedSeconds = 0,
    this.caloriesBurned = 0,
    this.completedExercises = 0,
    this.completion,
  });

  final WorkoutDetail detail;
  final int historyId;
  final WorkoutSessionPhase phase;
  final int currentIndex;
  final int currentRemainingSeconds;
  final int elapsedSeconds;
  final double caloriesBurned;
  final int completedExercises;
  final WorkoutCompletion? completion;

  int get totalExercises => detail.exercises.length;

  WorkoutExerciseDetail? get currentExercise =>
      currentIndex < detail.exercises.length
          ? detail.exercises[currentIndex]
          : null;

  bool get isActive =>
      phase == WorkoutSessionPhase.exercising ||
      phase == WorkoutSessionPhase.resting;

  WorkoutPlayerState copyWith({
    WorkoutDetail? detail,
    int? historyId,
    WorkoutSessionPhase? phase,
    int? currentIndex,
    int? currentRemainingSeconds,
    int? elapsedSeconds,
    double? caloriesBurned,
    int? completedExercises,
    WorkoutCompletion? completion,
  }) {
    return WorkoutPlayerState(
      detail: detail ?? this.detail,
      historyId: historyId ?? this.historyId,
      phase: phase ?? this.phase,
      currentIndex: currentIndex ?? this.currentIndex,
      currentRemainingSeconds:
          currentRemainingSeconds ?? this.currentRemainingSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      completedExercises: completedExercises ?? this.completedExercises,
      completion: completion ?? this.completion,
    );
  }

  @override
  List<Object?> get props => [
        detail,
        historyId,
        phase,
        currentIndex,
        currentRemainingSeconds,
        elapsedSeconds,
        caloriesBurned,
        completedExercises,
        completion,
      ];
}

/// State machine driving a single workout session.
///
/// The owning screen owns a one-second [Timer] that calls [tick].
class WorkoutPlayerController extends Notifier<WorkoutPlayerState?> {
  @override
  WorkoutPlayerState? build() => null;

  /// Opens a session: either brand new or resumed from [WorkoutPlayerArgs].
  Future<void> start(WorkoutPlayerArgs args) async {
    final AppUser? user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      throw StateError('Workout session requires a signed-in user');
    }

    final WorkoutDetail detail = await ref
        .watch(workoutLibraryRepositoryProvider)
        .getDetail(args.workoutId);

    int historyId = args.historyId ?? -1;
    int completed = 0;
    int elapsedSeconds = 0;

    if (args.historyId != null) {
      historyId = args.historyId!;
      final List<dynamic> rows = await ref
          .watch(exerciseHistoryRepositoryProvider)
          .getByWorkoutHistory(historyId);
      completed = rows.length.clamp(0, detail.exercises.length);
      if (args.startedAt != null) {
        elapsedSeconds =
            DateTime.now().difference(args.startedAt!).inSeconds.abs();
      }
    } else {
      historyId = await ref
          .watch(workoutSessionRepositoryProvider)
          .startSession(userId: user.id, workoutId: args.workoutId);
    }

    final WorkoutExerciseDetail? first = completed < detail.exercises.length
        ? detail.exercises[completed]
        : null;
    state = WorkoutPlayerState(
      detail: detail,
      historyId: historyId,
      phase: first == null
          ? WorkoutSessionPhase.idle
          : WorkoutSessionPhase.exercising,
      currentIndex: completed,
      currentRemainingSeconds: first?.durationSeconds ?? 0,
      elapsedSeconds: elapsedSeconds,
      completedExercises: completed,
    );

    if (first == null) {
      await _finish();
    }
  }

  /// Advances one wall-clock second of the session.
  void tick() {
    final WorkoutPlayerState? current = state;
    if (current == null || !current.isActive) return;

    WorkoutPlayerState next = current.copyWith(
      elapsedSeconds: current.elapsedSeconds + 1,
    );

    if (next.phase == WorkoutSessionPhase.exercising) {
      if (next.currentRemainingSeconds > 0) {
        next = next.copyWith(
          currentRemainingSeconds: next.currentRemainingSeconds - 1,
        );
        if (next.currentRemainingSeconds == 0) {
          _completeCurrentExercise();
          return;
        }
      }
    } else if (next.phase == WorkoutSessionPhase.resting) {
      if (next.currentRemainingSeconds > 0) {
        next = next.copyWith(
          currentRemainingSeconds: next.currentRemainingSeconds - 1,
        );
      }
      if (next.currentRemainingSeconds <= 0) {
        _advance();
        return;
      }
    }

    state = next;
  }

  /// Marks the current exercise as done, logs it and moves on.
  Future<void> completeCurrentExercise() => _completeCurrentExercise();

  Future<void> _completeCurrentExercise() async {
    final WorkoutPlayerState? current = state;
    final WorkoutExerciseDetail? exercise = current?.currentExercise;
    if (current == null || exercise == null) return;
    if (current.phase == WorkoutSessionPhase.resting) {
      _advance();
      return;
    }

    await ref.read(exerciseHistoryRepositoryProvider).insert(
      ExerciseHistory(
        workoutHistoryId: current.historyId,
        exerciseId: exercise.exercise.id,
        sets: exercise.sets,
        reps: exercise.reps,
        durationSeconds: exercise.durationSeconds,
        completedAt: DateTime.now(),
      ),
    );

    state = current.copyWith(
      caloriesBurned: current.caloriesBurned + exercise.estimatedCalories,
      completedExercises: current.completedExercises + 1,
    );
    _advance();
  }

  /// Skips the current exercise without logging it.
  void skipExercise() {
    final WorkoutPlayerState? current = state;
    if (current == null || current.currentExercise == null) return;
    _advance();
  }

  void _advance() {
    final WorkoutPlayerState? current = state;
    if (current == null) return;

    if (current.currentIndex + 1 >= current.detail.exercises.length) {
      _finish();
      return;
    }

    final int nextIndex = current.currentIndex + 1;
    final WorkoutExerciseDetail next = current.detail.exercises[nextIndex];
    final bool rest = next.restSeconds > 0;

    state = current.copyWith(
      currentIndex: nextIndex,
      phase: rest
          ? WorkoutSessionPhase.resting
          : WorkoutSessionPhase.exercising,
      currentRemainingSeconds: rest ? next.restSeconds : next.durationSeconds,
    );
  }

  Future<void> _finish() async {
    final WorkoutPlayerState? current = state;
    if (current == null) return;

    final int durationMinutes =
        (current.elapsedSeconds / 60).ceil().clamp(1, 1 << 31);
    final double calories = current.caloriesBurned;

    final WorkoutCompletion completion = await ref
        .watch(workoutSessionRepositoryProvider)
        .completeSession(
          historyId: current.historyId,
          durationMinutes: durationMinutes,
          caloriesBurned: calories,
          totalExercises: current.detail.exercises.length,
        );

    state = current.copyWith(
      phase: WorkoutSessionPhase.completed,
      completion: completion,
    );

    ref.invalidate(workoutLibraryControllerProvider);
    ref.invalidate(workoutHistoryProvider);
  }
}

final workoutPlayerControllerProvider =
    NotifierProvider<WorkoutPlayerController, WorkoutPlayerState?>(
      WorkoutPlayerController.new,
    );
