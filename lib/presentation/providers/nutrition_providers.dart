import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/daily_nutrition.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/food_filter.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/meal_category.dart';
import '../../domain/entities/meal_template_detail.dart';
import '../../domain/entities/nutrition_history.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';

/// Calendar day currently selected across the nutrition module.
final nutritionSelectedDateProvider = StateProvider<DateTime>((ref) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Loads and refreshes the daily nutrition aggregate for the selected date.
class NutritionDailyController extends AsyncNotifier<DailyNutrition> {
  @override
  Future<DailyNutrition> build() {
    final DateTime date = ref.watch(nutritionSelectedDateProvider);
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      throw StateError('Nutrition requires a signed-in user');
    }
    return ref.watch(nutritionRepositoryProvider).loadDaily(user.id, date);
  }

  Future<void> refresh() async {
    state = AsyncValue<DailyNutrition>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }
}

final nutritionDailyControllerProvider =
    AsyncNotifierProvider<NutritionDailyController, DailyNutrition>(
      NutritionDailyController.new,
    );

/// The six meal slots of the day.
final nutritionMealCategoriesProvider = FutureProvider<List<MealCategory>>((
  ref,
) async {
  return ref.watch(nutritionRepositoryProvider).getMealCategories();
});

/// The food category catalog (16 categories).
final nutritionFoodCategoriesProvider = Provider<List<FoodCategory>>(
  (ref) => FoodCategory.valuesInOrder,
);

/// Current food search text.
final nutritionFoodSearchQueryProvider = StateProvider<String>((ref) => '');

/// Currently applied food filters.
final nutritionFoodFilterProvider = StateProvider<FoodFilter>(
  (ref) => const FoodFilter(),
);

/// Combined search + filter results for the food database.
final nutritionFoodSearchResultsProvider =
    FutureProvider.autoDispose<List<FoodItem>>((ref) async {
      final String query = ref.watch(nutritionFoodSearchQueryProvider);
      final FoodFilter filter = ref.watch(nutritionFoodFilterProvider);
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return const <FoodItem>[];

      final FoodFilter effective = filter.query == query
          ? filter
          : filter.copyWith(query: query);
      if (effective.isEmpty) return const <FoodItem>[];
      return ref
          .watch(nutritionRepositoryProvider)
          .searchFoods(user.id, effective);
    });

/// The full food catalog for the current user (built-in + custom).
final nutritionCatalogProvider = FutureProvider.autoDispose<List<FoodItem>>((
  ref,
) async {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return const <FoodItem>[];
  return ref.watch(foodItemRepositoryProvider).getCatalog(user.id);
});

/// The user's favourite foods.
final nutritionFavoritesProvider = FutureProvider.autoDispose<List<FoodItem>>((
  ref,
) async {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return const <FoodItem>[];
  return ref.watch(nutritionRepositoryProvider).getFavorites(user.id);
});

/// Recently logged foods (distinct).
final nutritionRecentFoodsProvider =
    FutureProvider.autoDispose<List<FoodItem>>((ref) async {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return const <FoodItem>[];
      return ref.watch(nutritionRepositoryProvider).getRecentFoods(user.id);
    });

/// Frequently logged foods (distinct).
final nutritionFrequentFoodsProvider =
    FutureProvider.autoDispose<List<FoodItem>>((ref) async {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return const <FoodItem>[];
      return ref.watch(nutritionRepositoryProvider).getFrequentFoods(user.id);
    });

/// Saved meal templates for the current user.
final nutritionMealTemplatesProvider =
    FutureProvider.autoDispose<List<MealTemplateDetail>>((ref) async {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return const <MealTemplateDetail>[];
      return ref.watch(nutritionRepositoryProvider).getMealTemplates(user.id);
    });

/// History range currently being viewed (start, inclusive end).
final nutritionHistoryRangeProvider = StateProvider<({DateTime start, DateTime end})>(
  (ref) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime start = today.subtract(const Duration(days: 6));
    return (start: start, end: today);
  },
);

/// Nutrition history for the selected range.
final nutritionHistoryProvider = FutureProvider.autoDispose<NutritionHistory>((
  ref,
) async {
  final ({DateTime start, DateTime end}) range = ref.watch(
    nutritionHistoryRangeProvider,
  );
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) {
    return NutritionHistory(start: range.start, end: range.end);
  }
  return ref
      .watch(nutritionRepositoryProvider)
      .loadHistory(user.id, range.start, range.end);
});

/// Logs a serving of [food] into meal slot [mealTypeId] on [date].
Future<void> addFoodToLog(
  WidgetRef ref, {
  required FoodItem food,
  required int mealTypeId,
  double quantity = 1,
  DateTime? date,
}) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  await ref
      .read(nutritionRepositoryProvider)
      .addFood(user.id, food, mealTypeId: mealTypeId, quantity: quantity, date: date);
  ref.invalidate(nutritionDailyControllerProvider);
  ref.invalidate(nutritionRecentFoodsProvider);
  ref.invalidate(nutritionFrequentFoodsProvider);
}

/// Removes a logged food entry.
Future<void> removeFoodFromLog(WidgetRef ref, int logId) async {
  await ref.read(nutritionRepositoryProvider).deleteLog(logId);
  ref.invalidate(nutritionDailyControllerProvider);
  ref.invalidate(nutritionRecentFoodsProvider);
}

/// Edits the serving quantity of a log, rescaling its macro snapshot.
Future<void> updateLogQuantity(
  WidgetRef ref, {
  required FoodLog log,
  required double quantity,
}) async {
  if (quantity <= 0 || quantity == log.quantity) return;
  final double ratio = quantity / log.quantity;
  final FoodLog updated = log.copyWith(
    quantity: quantity,
    calories: log.calories * ratio,
    protein: log.protein * ratio,
    carbs: log.carbs * ratio,
    fat: log.fat * ratio,
    fiber: log.fiber * ratio,
    sugar: log.sugar * ratio,
  );
  await ref.read(nutritionRepositoryProvider).updateLog(updated);
  ref.invalidate(nutritionDailyControllerProvider);
}

/// Duplicates a log entry (one more serving of the same food).
Future<void> duplicateFoodLog(WidgetRef ref, int logId) async {
  await ref.read(nutritionRepositoryProvider).duplicateLog(logId);
  ref.invalidate(nutritionDailyControllerProvider);
  ref.invalidate(nutritionRecentFoodsProvider);
}

/// Copies yesterday's logged foods into the selected date.
Future<void> copyYesterdayMeals(WidgetRef ref) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  final DateTime date = ref.read(nutritionSelectedDateProvider);
  await ref
      .read(nutritionRepositoryProvider)
      .copyYesterdayMeals(user.id, date);
  ref.invalidate(nutritionDailyControllerProvider);
  ref.invalidate(nutritionRecentFoodsProvider);
}

/// Toggles the favourite flag of a food and refreshes the library.
Future<void> toggleFoodFavorite(WidgetRef ref, int foodItemId) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  await ref
      .read(nutritionRepositoryProvider)
      .toggleFavorite(user.id, foodItemId);
  ref.invalidate(nutritionFoodSearchResultsProvider);
  ref.invalidate(nutritionFavoritesProvider);
  ref.invalidate(nutritionCatalogProvider);
}

/// Logs every food of a saved meal template into [date].
Future<void> logMealTemplate(
  WidgetRef ref,
  int mealId, {
  DateTime? date,
}) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  final DateTime target =
      date ??
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
  await ref
      .read(nutritionRepositoryProvider)
      .logMealTemplate(user.id, mealId, target);
  ref.invalidate(nutritionDailyControllerProvider);
  ref.invalidate(nutritionRecentFoodsProvider);
}

/// Creates a saved meal template from the current selection.
Future<int> saveMealTemplate(
  WidgetRef ref, {
  required String name,
  required int categoryId,
  required List<FoodItem> foods,
  List<double> quantities = const <double>[],
}) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) {
    throw StateError('Nutrition requires a signed-in user');
  }
  final int mealId = await ref.read(nutritionRepositoryProvider).saveMealTemplate(
    user.id,
    name: name,
    categoryId: categoryId,
    foods: foods,
    quantities: quantities,
  );
  ref.invalidate(nutritionMealTemplatesProvider);
  return mealId;
}

/// Deletes a saved meal template.
Future<void> deleteMealTemplate(WidgetRef ref, int mealId) async {
  await ref.read(nutritionRepositoryProvider).deleteMealTemplate(mealId);
  ref.invalidate(nutritionMealTemplatesProvider);
}
