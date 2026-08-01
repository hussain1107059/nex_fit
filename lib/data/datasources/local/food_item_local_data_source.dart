import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/food_filter.dart';
import '../../../domain/entities/food_item.dart';
import '../../models/food_item_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `food_item` table (built-in + user foods) and
/// the per-user `food_favorite` join table.
class FoodItemLocalDataSource extends BaseLocalDataSource {
  FoodItemLocalDataSource({required super.database})
    : super(logName: 'FoodItemLocalDataSource');

  static const String favoriteTable = 'food_favorite';

  Future<int> insert(FoodItem item) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        FoodItemModel.table,
        FoodItemModel.toMap(item),
      );
    });
  }

  Future<void> update(FoodItem item) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        FoodItemModel.table,
        FoodItemModel.toMap(item),
        where: 'id = ?',
        whereArgs: <Object?>[item.id],
      );
    });
  }

  Future<FoodItem?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodItemModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return FoodItemModel.fromMap(rows.first);
    });
  }

  Future<List<FoodItem>> getBuiltIn() {
    return guard('get_built_in', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodItemModel.table,
        where: 'user_id IS NULL',
        orderBy: 'name ASC',
      );
      return rows.map(FoodItemModel.fromMap).toList();
    });
  }

  Future<List<FoodItem>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodItemModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'name ASC',
      );
      return rows.map(FoodItemModel.fromMap).toList();
    });
  }

  /// Full catalog visible to [userId]: built-in foods plus the user's own,
  /// each annotated with its favourite flag.
  Future<List<FoodItem>> getCatalog(String userId) {
    return guard('get_catalog', () async {
      final Database db = await dbConnection;
      final Set<int> favorites = await _favoriteIds(db, userId);
      final List<Map<String, Object?>> rows = await db.query(
        FoodItemModel.table,
        where: 'user_id IS NULL OR user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'name ASC',
      );
      return rows.map((Map<String, Object?> row) {
        final FoodItem item = FoodItemModel.fromMap(row);
        return item.copyWith(
          isFavorite: item.id != null && favorites.contains(item.id),
        );
      }).toList();
    });
  }

  /// Applies [filter] over the catalog and annotates favourite flags.
  Future<List<FoodItem>> search(FoodFilter filter, String userId) {
    return guard('search', () async {
      final Database db = await dbConnection;
      final Set<int> favorites = await _favoriteIds(db, userId);

      final String query = filter.query.trim().toLowerCase();
      final List<String> where = <String>['(user_id IS NULL OR user_id = ?)'];
      final List<Object?> args = <Object?>[userId];

      if (filter.favoritesOnly) {
        where.add(
          'id IN (SELECT food_item_id FROM $favoriteTable WHERE user_id = ?)',
        );
        args.add(userId);
      }
      if (filter.category != null) {
        where.add('category = ?');
        args.add(filter.category!.name);
      }
      if (filter.maxCalories != null) {
        where.add('calories <= ?');
        args.add(filter.maxCalories);
      }
      if (filter.minProtein != null) {
        where.add('protein >= ?');
        args.add(filter.minProtein);
      }
      if (query.isNotEmpty) {
        where.add('(LOWER(name) LIKE ? OR LOWER(brand) LIKE ?)');
        args.add('%$query%');
        args.add('%$query%');
      }

      final List<Map<String, Object?>> rows = await db.query(
        FoodItemModel.table,
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'name ASC',
      );
      return rows.map((Map<String, Object?> row) {
        final FoodItem item = FoodItemModel.fromMap(row);
        return item.copyWith(
          isFavorite: item.id != null && favorites.contains(item.id),
        );
      }).toList();
    });
  }

  /// Foods favourited by [userId], annotated with the flag set.
  Future<List<FoodItem>> getFavorites(String userId) {
    return guard('get_favorites', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT f.* FROM ${FoodItemModel.table} f '
        'INNER JOIN $favoriteTable fav ON fav.food_item_id = f.id '
        'WHERE fav.user_id = ? ORDER BY f.name ASC',
        <Object?>[userId],
      );
      return rows.map((Map<String, Object?> row) {
        return FoodItemModel.fromMap(row).copyWith(isFavorite: true);
      }).toList();
    });
  }

  Future<Set<int>> getFavoriteIds(String userId) {
    return guard('get_favorite_ids', () async {
      final Database db = await dbConnection;
      return _favoriteIds(db, userId);
    });
  }

  Future<void> addFavorite(String userId, int foodItemId) {
    return guard('add_favorite', () async {
      final Database db = await dbConnection;
      await db.insert(
        favoriteTable,
        <String, Object?>{
          'user_id': userId,
          'food_item_id': foodItemId,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  Future<void> removeFavorite(String userId, int foodItemId) {
    return guard('remove_favorite', () async {
      final Database db = await dbConnection;
      await db.delete(
        favoriteTable,
        where: 'user_id = ? AND food_item_id = ?',
        whereArgs: <Object?>[userId, foodItemId],
      );
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        FoodItemModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  Future<Set<int>> _favoriteIds(Database db, String userId) async {
    final List<Map<String, Object?>> rows = await db.query(
      favoriteTable,
      columns: <String>['food_item_id'],
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
    );
    return rows.map((row) => row['food_item_id'] as int).toSet();
  }
}
