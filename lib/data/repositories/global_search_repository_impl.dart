import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/workout.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/food_item_repository.dart';
import '../../domain/repositories/global_search_repository.dart';
import '../../domain/repositories/meal_repository.dart';
import '../../domain/repositories/workout_repository.dart';

/// Global search across the user's workouts, exercises, foods and meals.
class GlobalSearchRepositoryImpl implements GlobalSearchRepository {
  GlobalSearchRepositoryImpl({
    required this._workoutRepository,
    required this._exerciseRepository,
    required this._foodItemRepository,
    required this._mealRepository,
  });

  final WorkoutRepository _workoutRepository;
  final ExerciseRepository _exerciseRepository;
  final FoodItemRepository _foodItemRepository;
  final MealRepository _mealRepository;

  static const int _maxPerCategory = 5;

  @override
  Future<List<GlobalSearchResult>> search(String userId, String query) async {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const <GlobalSearchResult>[];

    final List<Object?> results = await Future.wait<Object?>([
      _workoutRepository.getByUserId(userId),
      _exerciseRepository.getBuiltIn(),
      _exerciseRepository.getByUserId(userId),
      _foodItemRepository.getBuiltIn(),
      _foodItemRepository.getByUserId(userId),
      _mealRepository.getByUserId(userId),
    ]);

    final List<Workout> workouts = results[0] as List<Workout>;
    final List<Exercise> builtInExercises = results[1] as List<Exercise>;
    final List<Exercise> userExercises = results[2] as List<Exercise>;
    final List<FoodItem> builtInFoods = results[3] as List<FoodItem>;
    final List<FoodItem> userFoods = results[4] as List<FoodItem>;
    final List<Meal> meals = results[5] as List<Meal>;

    final List<GlobalSearchResult> workoutMatches = <GlobalSearchResult>[];
    for (final Workout w in workouts) {
      if (!w.name.toLowerCase().contains(needle)) continue;
      workoutMatches.add(
        GlobalSearchResult(
          type: GlobalSearchType.workout,
          id: w.id,
          title: w.name,
          subtitle: '${w.durationMinutes ?? 0} min',
        ),
      );
    }

    final List<GlobalSearchResult> exerciseMatches = <GlobalSearchResult>[];
    final Set<String> seenExercises = <String>{};
    for (final Exercise e in <Exercise>[...builtInExercises, ...userExercises]) {
      if (!e.name.toLowerCase().contains(needle)) continue;
      if (!seenExercises.add(e.name)) continue;
      exerciseMatches.add(
        GlobalSearchResult(
          type: GlobalSearchType.exercise,
          id: e.id,
          title: e.name,
          subtitle: e.bodyPart ?? e.equipment,
        ),
      );
    }

    final List<GlobalSearchResult> foodMatches = <GlobalSearchResult>[];
    final Set<String> seenFoods = <String>{};
    for (final FoodItem f in <FoodItem>[...builtInFoods, ...userFoods]) {
      if (!f.name.toLowerCase().contains(needle)) continue;
      if (!seenFoods.add(f.name)) continue;
      foodMatches.add(
        GlobalSearchResult(
          type: GlobalSearchType.food,
          id: f.id,
          title: f.name,
          subtitle: f.brand ?? f.servingSize ?? f.category,
        ),
      );
    }

    final List<GlobalSearchResult> mealMatches = <GlobalSearchResult>[];
    for (final Meal m in meals) {
      if (!m.name.toLowerCase().contains(needle)) continue;
      mealMatches.add(
        GlobalSearchResult(
          type: GlobalSearchType.meal,
          id: m.id,
          title: m.name,
          subtitle: '${m.calories.round()} kcal',
        ),
      );
    }

    return <GlobalSearchResult>[
      ...workoutMatches.take(_maxPerCategory),
      ...exerciseMatches.take(_maxPerCategory),
      ...foodMatches.take(_maxPerCategory),
      ...mealMatches.take(_maxPerCategory),
    ];
  }
}
