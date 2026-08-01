import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../datasources/local/app_database.dart';
import '../models/food_item_model.dart';
import 'food_seed_data.dart';

/// Provisions the offline food database catalog.
///
/// Built-in foods are global and seeded once (`INSERT`/`UPDATE` by name with a
/// null `user_id`), so every account shares the same 200+ item catalog while
/// user-created foods stay personal. Safe to call repeatedly.
class FoodSeeder {
  FoodSeeder({
    required this._database,
    Logger? logger,
  }) : _logger = logger ?? Logger('FoodSeeder');

  final AppDatabase _database;
  final Logger _logger;

  Future<void> ensureSeeded() async {
    await _database.inTransaction((Transaction txn) async {
      final List<Map<String, Object?>> existing = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM ${FoodItemModel.table} '
        'WHERE user_id IS NULL',
      );
      final int count = existing.first['count'] as int? ?? 0;
      if (count >= kSeedFoods.length) return;

      _logger.info('Seeding ${kSeedFoods.length} built-in foods');
      final int now = DateTime.now().millisecondsSinceEpoch;
      int inserted = 0;
      int updated = 0;

      for (final SeedFood food in kSeedFoods) {
        final Map<String, Object?> values = <String, Object?>{
          'name': food.name,
          'brand': null,
          'category': food.category.name,
          'serving_size': food.servingSize,
          'serving_grams': food.servingGrams,
          'calories': food.calories,
          'protein': food.protein,
          'carbs': food.carbs,
          'fat': food.fat,
          'fiber': food.fiber,
          'sugar': food.sugar,
          'sodium': food.sodium,
          'potassium': food.potassium,
          'calcium': food.calcium,
          'iron': food.iron,
          'vitamin_a': food.vitaminA,
          'vitamin_c': food.vitaminC,
          'water_percentage': food.waterPercentage,
          'barcode': null,
          'image_path': null,
          'is_custom': 0,
          'created_at': now,
        };

        // Backfill existing built-in rows in place (keeps ids and therefore
        // any log/favorite links valid) and insert new catalog entries.
        final int changed = await txn.update(
          FoodItemModel.table,
          values,
          where: 'user_id IS NULL AND name = ?',
          whereArgs: <Object?>[food.name],
        );
        if (changed > 0) {
          updated++;
          continue;
        }
        await txn.insert(FoodItemModel.table, values);
        inserted++;
      }
      _logger.info('Built-in foods seeded (updated: $updated, inserted: $inserted)');
    });
  }
}
