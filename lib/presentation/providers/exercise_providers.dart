import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_filter.dart';
import '../../domain/entities/exercise_library.dart';
import '../../domain/entities/app_user.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';

/// Loads and refreshes the exercise catalog aggregate.
class ExerciseLibraryController extends AsyncNotifier<ExerciseLibraryData> {
  @override
  Future<ExerciseLibraryData> build() => _load();

  Future<ExerciseLibraryData> _load() async {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      throw StateError('Exercise library requires a signed-in user');
    }
    return ref.watch(exerciseRepositoryProvider).loadLibrary(user.id);
  }

  Future<void> refresh() async {
    state = AsyncValue<ExerciseLibraryData>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }
}

final exerciseLibraryControllerProvider =
    AsyncNotifierProvider<ExerciseLibraryController, ExerciseLibraryData>(
      ExerciseLibraryController.new,
    );

/// A single exercise by id, with the favourite flag resolved for the user.
final exerciseDetailProvider = FutureProvider.autoDispose
    .family<Exercise?, int>((ref, exerciseId) async {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return null;
      final Exercise? exercise = await ref
          .watch(exerciseRepositoryProvider)
          .getById(exerciseId);
      if (exercise == null) return null;
      final Set<int> favorites = await ref
          .watch(exerciseRepositoryProvider)
          .getFavoriteIds(user.id);
      final int? id = exercise.id;
      return exercise.copyWith(isFavorite: id != null && favorites.contains(id));
    });

/// Current text in the exercise search field.
final exerciseSearchQueryProvider = StateProvider<String>((ref) => '');

/// Currently applied exercise filters.
final exerciseFilterProvider = StateProvider<ExerciseFilter>(
  (ref) => const ExerciseFilter(),
);

/// Combined search + filter results for the library screen.
final exerciseSearchResultsProvider = FutureProvider.autoDispose<List<Exercise>>((
  ref,
) async {
  final String query = ref.watch(exerciseSearchQueryProvider);
  final ExerciseFilter filter = ref.watch(exerciseFilterProvider);
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return const <Exercise>[];

  final ExerciseFilter effective = filter.query == query
      ? filter
      : filter.copyWith(query: query);
  return ref
      .watch(exerciseRepositoryProvider)
      .search(effective, user.id);
});

/// The user's favourite exercises.
final exerciseFavoritesProvider = FutureProvider.autoDispose<List<Exercise>>((
  ref,
) async {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return const <Exercise>[];
  return ref.watch(exerciseRepositoryProvider).getFavorites(user.id);
});

/// Toggles the favourite flag of an exercise and refreshes the library.
Future<void> toggleExerciseFavorite(WidgetRef ref, int exerciseId) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  await ref
      .read(exerciseRepositoryProvider)
      .toggleFavorite(user.id, exerciseId);
  ref.invalidate(exerciseLibraryControllerProvider);
  ref.invalidate(exerciseSearchResultsProvider);
  ref.invalidate(exerciseFavoritesProvider);
  ref.invalidate(exerciseDetailProvider(exerciseId));
}

/// Arguments handed to the single-exercise player.
class ExercisePlayerArgs extends Equatable {
  const ExercisePlayerArgs({required this.exercise});

  final Exercise exercise;

  @override
  List<Object?> get props => [exercise];
}

/// Where the exercise player currently sits inside a set cycle.
enum ExercisePlayerPhase { idle, exercising, resting, completed }

/// Immutable snapshot of an active single-exercise session.
class ExercisePlayerState extends Equatable {
  const ExercisePlayerState({
    required this.exercise,
    this.phase = ExercisePlayerPhase.idle,
    this.currentSet = 1,
    this.currentRemainingSeconds = 0,
    this.elapsedSeconds = 0,
    this.completedSets = 0,
    this.caloriesBurned = 0,
  });

  final Exercise exercise;
  final ExercisePlayerPhase phase;

  /// 1-based index of the set being performed.
  final int currentSet;
  final int currentRemainingSeconds;
  final int elapsedSeconds;
  final int completedSets;
  final double caloriesBurned;

  int get totalSets => exercise.sets > 0 ? exercise.sets : 1;

  bool get isLastSet => currentSet >= totalSets;

  bool get isActive =>
      phase == ExercisePlayerPhase.exercising ||
      phase == ExercisePlayerPhase.resting;

  /// Estimated calories for a single completed set.
  double get caloriesPerSet {
    final double total = exercise.totalEstimatedCalories;
    return totalSets == 0 ? 0 : total / totalSets;
  }

  double get completionRatio {
    if (totalSets == 0) return 0;
    final double performed = completedSets + (currentSet - 1);
    return (performed / totalSets).clamp(0.0, 1.0);
  }

  ExercisePlayerState copyWith({
    Exercise? exercise,
    ExercisePlayerPhase? phase,
    int? currentSet,
    int? currentRemainingSeconds,
    int? elapsedSeconds,
    int? completedSets,
    double? caloriesBurned,
  }) {
    return ExercisePlayerState(
      exercise: exercise ?? this.exercise,
      phase: phase ?? this.phase,
      currentSet: currentSet ?? this.currentSet,
      currentRemainingSeconds:
          currentRemainingSeconds ?? this.currentRemainingSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      completedSets: completedSets ?? this.completedSets,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
    );
  }

  @override
  List<Object?> get props => [
    exercise,
    phase,
    currentSet,
    currentRemainingSeconds,
    elapsedSeconds,
    completedSets,
    caloriesBurned,
  ];
}

/// State machine driving a single-exercise session.
///
/// The owning screen owns a one-second [Timer] that calls [tick], mirroring
/// the workout player lifecycle.
class ExercisePlayerController extends Notifier<ExercisePlayerState?> {
  @override
  ExercisePlayerState? build() => null;

  void start(Exercise exercise) {
    state = ExercisePlayerState(
      exercise: exercise,
      phase: ExercisePlayerPhase.exercising,
      currentSet: 1,
      currentRemainingSeconds: exercise.durationSeconds,
    );
  }

  void tick() {
    final ExercisePlayerState? current = state;
    if (current == null || !current.isActive) return;

    ExercisePlayerState next = current.copyWith(
      elapsedSeconds: current.elapsedSeconds + 1,
    );

    if (next.phase == ExercisePlayerPhase.exercising) {
      if (next.currentRemainingSeconds > 0) {
        next = next.copyWith(
          currentRemainingSeconds: next.currentRemainingSeconds - 1,
        );
        if (next.currentRemainingSeconds == 0) {
          _completeSet();
          return;
        }
      }
    } else if (next.phase == ExercisePlayerPhase.resting) {
      if (next.currentRemainingSeconds > 0) {
        next = next.copyWith(
          currentRemainingSeconds: next.currentRemainingSeconds - 1,
        );
      }
      if (next.currentRemainingSeconds <= 0) {
        _advanceToNextSet();
        return;
      }
    }

    state = next;
  }

  /// Marks the current set as complete and moves on (or finishes).
  void completeSet() => _completeSet();

  void _completeSet() {
    final ExercisePlayerState? current = state;
    if (current == null || current.phase != ExercisePlayerPhase.exercising) {
      return;
    }

    final double calories = current.caloriesBurned + current.caloriesPerSet;
    if (current.isLastSet) {
      state = current.copyWith(
        phase: ExercisePlayerPhase.completed,
        completedSets: current.totalSets,
        caloriesBurned: calories,
      );
      return;
    }

    final int rest = current.exercise.restSeconds;
    state = current.copyWith(
      currentSet: current.currentSet + 1,
      phase: rest > 0
          ? ExercisePlayerPhase.resting
          : ExercisePlayerPhase.exercising,
      currentRemainingSeconds: rest > 0
          ? rest
          : current.exercise.durationSeconds,
      completedSets: current.completedSets + 1,
      caloriesBurned: calories,
    );
  }

  /// Skips the rest period and starts the next set.
  void skipRest() {
    final ExercisePlayerState? current = state;
    if (current == null || current.phase != ExercisePlayerPhase.resting) return;
    _advanceToNextSet();
  }

  void _advanceToNextSet() {
    final ExercisePlayerState? current = state;
    if (current == null) return;
    state = current.copyWith(
      phase: ExercisePlayerPhase.exercising,
      currentRemainingSeconds: current.exercise.durationSeconds,
    );
  }
}

final exercisePlayerControllerProvider =
    NotifierProvider<ExercisePlayerController, ExercisePlayerState?>(
      ExercisePlayerController.new,
    );
