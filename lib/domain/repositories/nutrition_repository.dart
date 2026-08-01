import '../entities/daily_nutrition.dart';
import '../entities/food_filter.dart';
import '../entities/food_item.dart';
import '../entities/food_log.dart';
import '../entities/meal_category.dart';
import '../entities/meal_template_detail.dart';
import '../entities/nutrition_history.dart';

/// Aggregates the offline nutrition domain: the food catalog, daily logging,
/// meal planning and nutrition history.
abstract interface class NutritionRepository {
  /// Seeds the built-in food catalog. Idempotent.
  Future<void> ensureSeeded();

  /// The six meal slots of the day, ordered.
  Future<List<MealCategory>> getMealCategories();

  /// Aggregated nutrition state for [date].
  Future<DailyNutrition> loadDaily(String userId, DateTime date);

  /// Logs one serving of [food] into meal slot [mealTypeId] on [date].
  Future<int> addFood(
    String userId,
    FoodItem food, {
    required int mealTypeId,
    double quantity = 1,
    DateTime? date,
  });

  Future<void> updateLog(FoodLog log);

  Future<void> deleteLog(int logId);

  /// Duplicates a food log entry (adds another serving of the same food).
  Future<void> duplicateLog(int logId);

  /// Copies every food logged on the previous day into [targetDate],
  /// preserving each entry's meal slot.
  Future<void> copyYesterdayMeals(String userId, DateTime targetDate);

  /// Searches the catalog with [filter].
  Future<List<FoodItem>> searchFoods(String userId, FoodFilter filter);

  Future<List<FoodItem>> getFavorites(String userId);

  Future<List<FoodItem>> getRecentFoods(String userId);

  Future<List<FoodItem>> getFrequentFoods(String userId);

  Future<bool> toggleFavorite(String userId, int foodItemId);

  /// Saved meal templates enriched with their component foods.
  Future<List<MealTemplateDetail>> getMealTemplates(String userId);

  /// Creates a saved meal template from [foods] (+ matching [quantities]).
  Future<int> saveMealTemplate(
    String userId, {
    required String name,
    required int categoryId,
    required List<FoodItem> foods,
    List<double> quantities = const <double>[],
  });

  Future<void> deleteMealTemplate(int mealId);

  /// Logs every food of a saved template into [date].
  Future<void> logMealTemplate(String userId, int mealId, DateTime date);

  /// Day-by-day totals for the inclusive range [start]-[end].
  Future<NutritionHistory> loadHistory(
    String userId,
    DateTime start,
    DateTime end,
  );
}
