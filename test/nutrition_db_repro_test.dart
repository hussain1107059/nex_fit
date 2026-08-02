import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/constants/app_constants.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/food_item_local_data_source.dart';
import 'package:nexfit/data/datasources/local/food_log_local_data_source.dart';
import 'package:nexfit/data/datasources/local/meal_category_local_data_source.dart';
import 'package:nexfit/data/datasources/local/meal_item_local_data_source.dart';
import 'package:nexfit/data/datasources/local/meal_local_data_source.dart';
import 'package:nexfit/data/datasources/local/user_profile_local_data_source.dart';
import 'package:nexfit/data/datasources/local/water_log_local_data_source.dart';
import 'package:nexfit/data/repositories/food_item_repository_impl.dart';
import 'package:nexfit/data/repositories/food_log_repository_impl.dart';
import 'package:nexfit/data/repositories/meal_category_repository_impl.dart';
import 'package:nexfit/data/repositories/meal_item_repository_impl.dart';
import 'package:nexfit/data/repositories/meal_repository_impl.dart';
import 'package:nexfit/data/repositories/nutrition_repository_impl.dart';
import 'package:nexfit/data/repositories/user_fitness_profile_repository_impl.dart';
import 'package:nexfit/data/repositories/water_log_repository_impl.dart';
import 'package:nexfit/data/services/food_seeder.dart';
import 'package:nexfit/domain/entities/food_filter.dart';
import 'package:nexfit/domain/entities/food_item.dart';
import 'package:nexfit/domain/entities/meal_category.dart';
import 'package:nexfit/domain/entities/meal_slot.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  AppDatabase? database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() async {
    await database?.close();
  });

  late NutritionRepositoryImpl repo;

  Future<void> setUpRepo() async {
    await database?.close();
    final String dbPath = path.join(
      await databaseFactory.getDatabasesPath(),
      AppConstants.databaseName,
    );
    await databaseFactory.deleteDatabase(dbPath);

    final AppDatabase fresh = AppDatabase();
    database = fresh;
    final db = await fresh.database;
    expect(db, isNotNull);

    await db.insert('users', <String, Object?>{
      'id': 'repro-user',
      'name': 'Repro',
      'email': 'repro@example.com',
      'provider': 'email',
    });

    repo = NutritionRepositoryImpl(
      foodItemRepository: FoodItemRepositoryImpl(
        FoodItemLocalDataSource(database: fresh),
      ),
      foodLogRepository: FoodLogRepositoryImpl(
        FoodLogLocalDataSource(database: fresh),
      ),
      mealCategoryRepository: MealCategoryRepositoryImpl(
        MealCategoryLocalDataSource(database: fresh),
      ),
      mealRepository: MealRepositoryImpl(
        MealLocalDataSource(database: fresh),
      ),
      mealItemRepository: MealItemRepositoryImpl(
        MealItemLocalDataSource(database: fresh),
      ),
      waterLogRepository: WaterLogRepositoryImpl(
        WaterLogLocalDataSource(database: fresh),
      ),
      userProfileRepository: UserFitnessProfileRepositoryImpl(
        UserProfileLocalDataSource(database: fresh),
      ),
      foodSeeder: FoodSeeder(database: fresh),
    );
  }

  test('loadDaily works on an empty day (no unmodifiable-list crash)',
      () async {
    await setUpRepo();
    final DateTime today = DateTime.now();

    final daily = await repo.loadDaily('repro-user', today);

    expect(daily.calories, 0);
    expect(daily.slots, isNotEmpty);
    expect(daily.targetCalories, 2000);
  });

  test('loadDaily aggregates logged foods into their meal slot', () async {
    await setUpRepo();
    final DateTime today = DateTime.now();
    await repo.ensureSeeded();

    final List<FoodItem> catalog = await repo.searchFoods(
      'repro-user',
      const FoodFilter(query: 'rice'),
    );
    expect(catalog, isNotEmpty, reason: 'seeded catalog should contain rice');
    final FoodItem food = catalog.first;

    final List<MealCategory> categories = await repo.getMealCategories();
    expect(categories, isNotEmpty);
    final int breakfastId = categories.firstWhere(
      (MealCategory c) => c.slug == 'breakfast',
    ).id!;

    await repo.addFood(
      'repro-user',
      food,
      mealTypeId: breakfastId,
      quantity: 1,
      date: today,
    );

    final daily = await repo.loadDaily('repro-user', today);

    expect(daily.itemCount, 1);
    expect(daily.calories, greaterThan(0));
    final MealSlot breakfast = daily.slots.firstWhere(
      (MealSlot slot) => slot.category.slug == 'breakfast',
    );
    expect(breakfast.items, hasLength(1));
  });
}
