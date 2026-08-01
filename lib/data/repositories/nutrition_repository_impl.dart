import '../../domain/entities/daily_nutrition.dart';
import '../../domain/entities/food_filter.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/food_log_entry.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/meal_category.dart';
import '../../domain/entities/meal_item.dart';
import '../../domain/entities/meal_slot.dart';
import '../../domain/entities/meal_template_detail.dart';
import '../../domain/entities/nutrition_day_summary.dart';
import '../../domain/entities/nutrition_history.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/water_log.dart';
import '../../domain/repositories/food_item_repository.dart';
import '../../domain/repositories/food_log_repository.dart';
import '../../domain/repositories/meal_category_repository.dart';
import '../../domain/repositories/meal_item_repository.dart';
import '../../domain/repositories/meal_repository.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../../domain/repositories/user_fitness_profile_repository.dart';
import '../../domain/repositories/water_log_repository.dart';
import '../services/food_seeder.dart';

/// Aggregates the nutrition domain from the low level repositories.
class NutritionRepositoryImpl implements NutritionRepository {
  NutritionRepositoryImpl({
    required this.foodItemRepository,
    required this.foodLogRepository,
    required this.mealCategoryRepository,
    required this.mealRepository,
    required this.mealItemRepository,
    required this.waterLogRepository,
    required this.userProfileRepository,
    required this.foodSeeder,
  });

  final FoodItemRepository foodItemRepository;
  final FoodLogRepository foodLogRepository;
  final MealCategoryRepository mealCategoryRepository;
  final MealRepository mealRepository;
  final MealItemRepository mealItemRepository;
  final WaterLogRepository waterLogRepository;
  final UserFitnessProfileRepository userProfileRepository;
  final FoodSeeder foodSeeder;

  @override
  Future<void> ensureSeeded() => foodSeeder.ensureSeeded();

  @override
  Future<List<MealCategory>> getMealCategories() =>
      mealCategoryRepository.getAll();

  @override
  Future<DailyNutrition> loadDaily(String userId, DateTime date) async {
    await ensureSeeded();

    final (DateTime start, DateTime end) = _dayBounds(date);
    final List<FoodLog> logs = await foodLogRepository.getByDateRange(
      userId,
      start,
      end,
    );
    final List<MealCategory> categories = await mealCategoryRepository.getAll();
    final List<FoodItem> catalog = await foodItemRepository.getCatalog(userId);
    final Map<int, FoodItem> foodsById = <int, FoodItem>{
      for (final FoodItem food in catalog)
        if (food.id != null) food.id!: food,
    };

    final UserProfile? profile = await userProfileRepository.getById(userId);
    final List<WaterLog> waterLogs = await waterLogRepository.getByDateRange(
      userId,
      start,
      end,
    );
    final int waterMl = waterLogs.fold(
      0,
      (int sum, WaterLog log) => sum + log.amountMl,
    );

    final Map<int, List<FoodLogEntry>> grouped = <int, List<FoodLogEntry>>{};
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    double fiber = 0;
    double sugar = 0;

    for (final FoodLog log in logs) {
      calories += log.calories;
      protein += log.protein;
      carbs += log.carbs;
      fat += log.fat;
      fiber += log.fiber;
      sugar += log.sugar;

      final int slotId = _slotIdFor(log, categories);
      final FoodLogEntry entry = FoodLogEntry(
        log: log,
        food: log.foodItemId == null ? null : foodsById[log.foodItemId],
      );
      grouped.putIfAbsent(slotId, () => <FoodLogEntry>[]).add(entry);
    }

    final List<MealSlot> slots = categories.map((MealCategory category) {
      final List<FoodLogEntry> items =
          grouped[category.id] ?? const <FoodLogEntry>[];
      items.sort((FoodLogEntry a, FoodLogEntry b) {
        final int byTime = a.log.loggedAt.compareTo(b.log.loggedAt);
        return byTime != 0
            ? byTime
            : (a.log.createdAt.compareTo(b.log.createdAt));
      });
      return MealSlot(category: category, items: items);
    }).toList();

    final double targetCalories = profile?.targetCalories ?? 2000;
    final double targetProtein = profile?.targetProtein ?? 0;
    final double targetCarbs = profile?.targetCarbs ?? 0;
    final double targetFat = profile?.targetFat ?? 0;
    final int targetWaterMl = profile?.targetWaterMl ?? 2500;

    final bool goalMet = targetCalories > 0 &&
        calories >= targetCalories * 0.5 &&
        calories <= targetCalories;

    return DailyNutrition(
      date: start,
      slots: slots,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      waterMl: waterMl,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCarbs: targetCarbs,
      targetFat: targetFat,
      targetWaterMl: targetWaterMl,
      isGoalMet: goalMet,
    );
  }

  @override
  Future<int> addFood(
    String userId,
    FoodItem food, {
    required int mealTypeId,
    double quantity = 1,
    DateTime? date,
  }) {
    final DateTime target = _normalize(date ?? DateTime.now());
    final FoodLog log = _buildLog(
      userId,
      food,
      mealTypeId: mealTypeId,
      quantity: quantity,
      at: target,
    );
    return foodLogRepository.insert(log);
  }

  @override
  Future<void> updateLog(FoodLog log) => foodLogRepository.update(log);

  @override
  Future<void> deleteLog(int logId) => foodLogRepository.delete(logId);

  @override
  Future<void> duplicateLog(int logId) async {
    final FoodLog? log = await foodLogRepository.getById(logId);
    if (log == null) return;
    final DateTime now = DateTime.now();
    final FoodLog copy = log.copyWith(
      id: null,
      loggedAt: now,
      createdAt: now,
    );
    await foodLogRepository.insert(copy);
  }

  @override
  Future<void> copyYesterdayMeals(
    String userId,
    DateTime targetDate,
  ) async {
    final DateTime target = _normalize(targetDate);
    final DateTime yesterday = target.subtract(const Duration(days: 1));
    final (DateTime start, DateTime end) = _dayBounds(yesterday);
    final List<FoodLog> yesterdayLogs = await foodLogRepository.getByDateRange(
      userId,
      start,
      end,
    );
    if (yesterdayLogs.isEmpty) return;

    final DateTime now = DateTime.now();
    final List<FoodLog> copies = yesterdayLogs.map((FoodLog log) {
      return log.copyWith(
        id: null,
        loggedAt: _shiftToDay(log.loggedAt, target),
        createdAt: now,
      );
    }).toList();
    await foodLogRepository.insertAll(copies);
  }

  @override
  Future<List<FoodItem>> searchFoods(String userId, FoodFilter filter) =>
      foodItemRepository.search(filter, userId);

  @override
  Future<List<FoodItem>> getFavorites(String userId) =>
      foodItemRepository.getFavorites(userId);

  @override
  Future<List<FoodItem>> getRecentFoods(String userId) =>
      foodLogRepository.getRecentFoods(userId);

  @override
  Future<List<FoodItem>> getFrequentFoods(String userId) =>
      foodLogRepository.getFrequentFoods(userId);

  @override
  Future<bool> toggleFavorite(String userId, int foodItemId) =>
      foodItemRepository.toggleFavorite(userId, foodItemId);

  @override
  Future<List<MealTemplateDetail>> getMealTemplates(String userId) async {
    final List<Meal> meals = await mealRepository.getByUserId(userId);
    if (meals.isEmpty) return const <MealTemplateDetail>[];

    final Map<int, MealCategory> categoriesById = <int, MealCategory>{
      for (final MealCategory category in await mealCategoryRepository.getAll())
        if (category.id != null) category.id!: category,
    };
    final Map<int, FoodItem> foodsById = <int, FoodItem>{
      for (final FoodItem food in await foodItemRepository.getCatalog(userId))
        if (food.id != null) food.id!: food,
    };

    final List<MealTemplateDetail> templates = <MealTemplateDetail>[];
    for (final Meal meal in meals) {
      final List<MealItem> items = await mealItemRepository.getByMeal(meal.id!);
      templates.add(
        MealTemplateDetail(
          meal: meal,
          category: meal.categoryId == null
              ? null
              : categoriesById[meal.categoryId],
          items: items,
          foods: items
              .map((MealItem item) => foodsById[item.foodItemId])
              .whereType<FoodItem>()
              .toList(),
        ),
      );
    }
    templates.sort((MealTemplateDetail a, MealTemplateDetail b) {
      final int byName = a.meal.name.compareTo(b.meal.name);
      return byName != 0 ? byName : a.meal.id!.compareTo(b.meal.id!);
    });
    return templates;
  }

  @override
  Future<int> saveMealTemplate(
    String userId, {
    required String name,
    required int categoryId,
    required List<FoodItem> foods,
    List<double> quantities = const <double>[],
  }) async {
    final DateTime now = DateTime.now();
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    for (int index = 0; index < foods.length; index++) {
      final double quantity = index < quantities.length
          ? quantities[index]
          : 1;
      calories += foods[index].calories * quantity;
      protein += foods[index].protein * quantity;
      carbs += foods[index].carbs * quantity;
      fat += foods[index].fat * quantity;
    }

    final Meal meal = Meal(
      userId: userId,
      categoryId: categoryId,
      name: name.trim(),
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      createdAt: now,
      updatedAt: now,
    );
    final int mealId = await mealRepository.insert(meal);

    final List<MealItem> items = <MealItem>[
      for (int index = 0; index < foods.length; index++)
        MealItem(
          mealId: mealId,
          foodItemId: foods[index].id!,
          quantity: index < quantities.length ? quantities[index] : 1,
          sortOrder: index,
        ),
    ];
    if (items.isNotEmpty) {
      await mealItemRepository.insertAll(items);
    }
    return mealId;
  }

  @override
  Future<void> deleteMealTemplate(int mealId) async {
    await mealItemRepository.deleteByMeal(mealId);
    await mealRepository.delete(mealId);
  }

  @override
  Future<void> logMealTemplate(
    String userId,
    int mealId,
    DateTime date,
  ) async {
    final Meal? meal = await mealRepository.getById(mealId);
    if (meal == null) return;
    final List<MealItem> items = await mealItemRepository.getByMeal(mealId);
    if (items.isEmpty) return;

    final Map<int, FoodItem> foodsById = <int, FoodItem>{
      for (final FoodItem food in await foodItemRepository.getCatalog(userId))
        if (food.id != null) food.id!: food,
    };

    final DateTime target = _normalize(date);
    final List<FoodLog> logs = <FoodLog>[];
    for (int index = 0; index < items.length; index++) {
      final MealItem item = items[index];
      final FoodItem? food = foodsById[item.foodItemId];
      if (food == null) continue;
      logs.add(
        _buildLog(
          userId,
          food,
          mealTypeId: meal.categoryId ?? 1,
          quantity: item.quantity,
          at: DateTime(target.year, target.month, target.day, 12, 0)
              .add(Duration(minutes: index)),
        ),
      );
    }
    if (logs.isNotEmpty) {
      await foodLogRepository.insertAll(logs);
    }
  }

  @override
  Future<NutritionHistory> loadHistory(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    await ensureSeeded();

    final (DateTime dayStart, DateTime dayEnd) = _dayBounds(start);
    final int dayCount = end.difference(start).inDays + 1;
    final List<NutritionDaySummary> days = <NutritionDaySummary>[];

    for (int offset = 0; offset < dayCount; offset++) {
      final DateTime day = dayStart.add(Duration(days: offset));
      if (day.isAfter(dayEnd)) break;

      final (DateTime from, DateTime to) = _dayBounds(day);
      final List<FoodLog> logs = await foodLogRepository.getByDateRange(
        userId,
        from,
        to,
      );
      double calories = 0;
      double protein = 0;
      double carbs = 0;
      double fat = 0;
      double fiber = 0;
      double sugar = 0;
      for (final FoodLog log in logs) {
        calories += log.calories;
        protein += log.protein;
        carbs += log.carbs;
        fat += log.fat;
        fiber += log.fiber;
        sugar += log.sugar;
      }

      final List<WaterLog> waterLogs = await waterLogRepository.getByDateRange(
        userId,
        from,
        to,
      );
      final int waterMl = waterLogs.fold(
        0,
        (int sum, WaterLog log) => sum + log.amountMl,
      );

      days.add(
        NutritionDaySummary(
          date: from,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fiber: fiber,
          sugar: sugar,
          waterMl: waterMl,
          itemCount: logs.length,
        ),
      );
    }

    return NutritionHistory(start: dayStart, end: dayEnd, days: days);
  }

  FoodLog _buildLog(
    String userId,
    FoodItem food, {
    required int mealTypeId,
    required double quantity,
    required DateTime at,
  }) {
    return FoodLog(
      userId: userId,
      foodItemId: food.id,
      mealTypeId: mealTypeId,
      quantity: quantity,
      servingSize: food.servingSize,
      calories: food.calories * quantity,
      protein: food.protein * quantity,
      carbs: food.carbs * quantity,
      fat: food.fat * quantity,
      fiber: food.fiber * quantity,
      sugar: food.sugar * quantity,
      loggedAt: at,
      createdAt: DateTime.now(),
    );
  }

  int _slotIdFor(FoodLog log, List<MealCategory> categories) {
    if (log.mealTypeId != null) {
      for (final MealCategory category in categories) {
        if (category.id == log.mealTypeId) return category.id!;
      }
    }
    if (categories.isNotEmpty) return categories.first.id!;
    return 1;
  }

  /// Midnight → midnight for a day, using the local timezone.
  (DateTime, DateTime) _dayBounds(DateTime date) {
    final DateTime start = _normalize(date);
    return (start, start.add(const Duration(days: 1)));
  }

  DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Keeps the time-of-day of [source] but moves it to [target]'s calendar day.
  DateTime _shiftToDay(DateTime source, DateTime target) =>
      DateTime(
        target.year,
        target.month,
        target.day,
        source.hour,
        source.minute,
        source.second,
      );
}
