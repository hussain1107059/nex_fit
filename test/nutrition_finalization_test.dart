import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
import 'package:nexfit/domain/entities/food_category.dart';
import 'package:nexfit/domain/entities/food_filter.dart';
import 'package:nexfit/domain/entities/food_log.dart';
import 'package:nexfit/domain/entities/food_log_entry.dart';
import 'package:nexfit/domain/entities/meal_category.dart';
import 'package:nexfit/domain/entities/meal_slot.dart';
import 'package:nexfit/l10n/app_localizations.dart';
import 'package:nexfit/l10n/app_localizations_bs.dart';
import 'package:nexfit/l10n/app_localizations_en.dart';
import 'package:nexfit/presentation/screens/nutrition/widgets/meal_slot_card.dart';
import 'package:nexfit/presentation/screens/nutrition/widgets/nutrition_date_format.dart';

/// PROMPT 30 — Nutrition experience finalization.
///
/// The meal-slot names are now localized by slug (the DB stores English names
/// that used to leak into the Bangla UI), four user-visible strings carried
/// corrupted `Â`/`Ã` bytes that rendered literally, the template builder's
/// food tiles were a dead `onTap`, the template food picker bypassed go_router,
/// food search ignored the active section and fired a query per keystroke, the
/// history day-list silently vanished when empty, and search did not self-seed.
///
/// See `docs/NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §26.

class _Harness {
  _Harness(this.db);

  final AppDatabase db;

  late final NutritionRepositoryImpl repo;

  Future<void> init() async {
    final raw = await db.database;
    await raw.insert('users', <String, Object?>{
      'id': 'u-1',
      'name': 'Rahim',
      'email': 'rahim@example.com',
      'provider': 'email',
    });

    repo = NutritionRepositoryImpl(
      foodItemRepository: FoodItemRepositoryImpl(
        FoodItemLocalDataSource(database: db),
      ),
      foodLogRepository: FoodLogRepositoryImpl(
        FoodLogLocalDataSource(database: db),
      ),
      mealCategoryRepository: MealCategoryRepositoryImpl(
        MealCategoryLocalDataSource(database: db),
      ),
      mealRepository: MealRepositoryImpl(
        MealLocalDataSource(database: db),
      ),
      mealItemRepository: MealItemRepositoryImpl(
        MealItemLocalDataSource(database: db),
      ),
      waterLogRepository: WaterLogRepositoryImpl(
        WaterLogLocalDataSource(database: db),
      ),
      userProfileRepository: UserFitnessProfileRepositoryImpl(
        UserProfileLocalDataSource(database: db),
      ),
      foodSeeder: FoodSeeder(database: db),
    );
  }

  Future<void> close() => db.close();
}

const Set<String> _canonicalSlugs = <String>{
  'breakfast',
  'morning_snack',
  'lunch',
  'evening_snack',
  'dinner',
  'late_night_snack',
};

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late _Harness harness;

  setUp(() async {
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/nutrition_finalization.db',
    );
    harness = _Harness(AppDatabase(databaseName: 'nutrition_finalization.db'));
    await harness.init();
  });

  tearDown(() async {
    await harness.close();
  });

  group('PROMPT 30 nutrition finalization', () {
    test('meal categories are seeded with the six canonical slugs and ids', () async {
      final List<MealCategory> categories = await harness.repo.getMealCategories();

      expect(
        categories.map((MealCategory c) => c.slug).toSet(),
        _canonicalSlugs,
        reason: 'the meal-slot label helper maps exactly these six slugs',
      );
      for (final MealCategory category in categories) {
        expect(category.id, isNotNull,
            reason: 'slots are keyed by category id for logging');
        expect(category.name, isNotEmpty);
      }
    });

    test('daily slots always carry categories that resolve to known slugs', () async {
      final daily = await harness.repo.loadDaily('u-1', DateTime.now());

      expect(
        daily.slots.map((MealSlot s) => s.category.slug).toSet(),
        _canonicalSlugs,
        reason: 'every rendered slot must map to a localized label',
      );
    });

    test('seeded catalog items expose ids for food-detail navigation', () async {
      final List<MealCategory> categories = await harness.repo.getMealCategories();
      final int breakfastId = categories
          .firstWhere((MealCategory c) => c.slug == 'breakfast')
          .id!;

      final foods = await harness.repo.searchFoods(
        'u-1',
        const FoodFilter(category: FoodCategory.rice),
      );
      expect(foods, isNotEmpty);
      for (final food in foods) {
        expect(food.id, isNotNull,
            reason: 'food tiles navigate to foodDetailPath(id)');
      }
      expect(breakfastId, isPositive);
    });

    test('search without filters self-seeds and returns the catalog', () async {
      final foods = await harness.repo.searchFoods('u-1', const FoodFilter());

      expect(foods.length, greaterThanOrEqualTo(200),
          reason: 'the catalog seed provisions 200+ foods and search must '
              'seed on first use like the workout library');
    });

    test('category-filtered search matches the requested category', () async {
      final rice = await harness.repo.searchFoods(
        'u-1',
        const FoodFilter(category: FoodCategory.rice),
      );
      expect(rice, isNotEmpty);
      for (final food in rice) {
        expect(food.categoryEnum, FoodCategory.rice,
            reason: 'the filter chips write the same category the search uses');
      }
    });

    test('no file under lib/ contains the corrupted Â/Ã sequences', () {
      final Directory root = Directory('lib');
      expect(root.existsSync(), isTrue);
      final List<File> dartFiles = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList();
      expect(dartFiles, isNotEmpty);
      for (final File file in dartFiles) {
        final String content = file.readAsStringSync();
        expect(content.contains('\u00C2'), isFalse,
            reason: 'corrupted Â byte in ${file.path}');
        expect(content.contains('\u00C3'), isFalse,
            reason: 'corrupted Ã byte in ${file.path}');
      }
    });

    test('l10n exposes localized meal-slot and month labels for en and bs', () {
      final AppLocalizations en = AppLocalizationsEn();
      final AppLocalizations bs = AppLocalizationsBs();

      expect(en.mealCategoryBreakfast, 'Breakfast');
      expect(en.mealCategoryLateNightSnack, 'Late-night snack');
      expect(en.monthAug, 'Aug');
      expect(bs.mealCategoryBreakfast, 'সকালের নাস্তা');
      expect(bs.monthAug, 'আগস্ট');
    });

    test('formatNutritionDate uses localized month abbreviations', () {
      final DateTime august = DateTime(2026, 8, 15);

      expect(formatNutritionDate(august, AppLocalizationsEn()), contains('Aug'));
      expect(formatNutritionDate(august, AppLocalizationsBs()), contains('আগস্ট'));
    });
  });

  group('PROMPT 30 nutrition finalization widgets', () {
    testWidgets('MealSlotCard renders a clean × · separator and a localized '
        'slot name', (WidgetTester tester) async {
      final MealCategory category = MealCategory(
        id: 1,
        name: 'Breakfast',
        slug: 'breakfast',
        createdAt: DateTime(2026),
      );
      final DateTime now = DateTime(2026, 8, 15);
      final FoodLog log = FoodLog(
        userId: 'u-1',
        foodItemId: 1,
        quantity: 1.5,
        protein: 3,
        carbs: 2,
        fat: 1,
        loggedAt: now,
        createdAt: now,
      );
      final MealSlot slot = MealSlot(
        category: category,
        items: <FoodLogEntry>[FoodLogEntry(log: log)],
      );

      await tester.pumpWidget(_localizedApp(MealSlotCard(slot: slot)));
      await tester.pumpAndSettle();

      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.textContaining('×'), findsOneWidget);
      expect(find.textContaining('·'), findsOneWidget);
      expect(find.textContaining('Ã'), findsNothing);
      expect(find.textContaining('Â'), findsNothing);
    });

    testWidgets('MealSlotCard falls back to the raw name for unknown slugs', (
      WidgetTester tester,
    ) async {
      final MealCategory category = MealCategory(
        id: 9,
        name: 'Custom Meal',
        slug: 'custom',
        createdAt: DateTime(2026),
      );

      await tester.pumpWidget(
        _localizedApp(MealSlotCard(slot: MealSlot(category: category))),
      );

      expect(find.text('Custom Meal'), findsOneWidget);
    });
  });
}

Widget _localizedApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}