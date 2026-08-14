import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/food_filter.dart';
import '../../../domain/entities/food_item.dart';
import '../../models/food_item_model.dart';
import '../../services/sync/sync_event_recorder.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `food_item` table (built-in + user foods) and
/// the per-user `food_favorite` join table.
class FoodItemLocalDataSource extends BaseLocalDataSource {
  FoodItemLocalDataSource({required super.database})
    : super(logName: 'FoodItemLocalDataSource');

  static const String favoriteTable = 'food_favorite';

  Future<int> insert(FoodItem item) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = FoodItemModel.toMap(item);
        if (item.userId != null) {
          // Custom (user-owned) rows enter the outbox with a fresh uuid.
          values['uuid'] = SyncableDao.newUuid();
          values['created_at'] = now;
          values['updated_at'] = now;
          values['row_version'] = SyncableDao.firstRowVersion;
        }
        final int id = await txn.insert(FoodItemModel.table, values);
        if (item.userId != null) {
          await SyncableDao.recordCreate(
            txn,
            entity: FoodItemModel.table,
            entityId: '$id',
            userId: item.userId!,
          );
        }
        return id;
      });
    });
  }

  Future<void> update(FoodItem item) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        if (item.userId == null) {
          // Master row: local-only catalog update, no outbox event.
          await txn.update(
            FoodItemModel.table,
            FoodItemModel.toMap(item),
            where: 'id = ?',
            whereArgs: <Object?>[item.id],
          );
          return;
        }
        final List<Map<String, Object?>> existing = await txn.query(
          FoodItemModel.table,
          where: 'id = ?',
          whereArgs: <Object?>[item.id],
          limit: 1,
        );
        if (existing.isEmpty) return;
        final Map<String, Object?> row = existing.first;
        final int baseVersion = _version(row);
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = FoodItemModel.toMap(item);
        values['uuid'] = row['uuid'] as String? ?? SyncableDao.newUuid();
        values['created_at'] = row['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          FoodItemModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[item.id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: FoodItemModel.table,
          entityId: '${item.id}',
          userId: item.userId!,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<FoodItem?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodItemModel.table,
        where: 'id = ? AND deleted_at IS NULL',
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
        where: 'user_id = ? AND deleted_at IS NULL',
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
        where: '(user_id IS NULL AND deleted_at IS NULL) '
            'OR (user_id = ? AND deleted_at IS NULL)',
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
      final List<String> where = <String>[
        '((user_id IS NULL AND deleted_at IS NULL) '
            'OR (user_id = ? AND deleted_at IS NULL))',
      ];
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
        'WHERE fav.user_id = ? AND fav.deleted_at IS NULL '
        'AND f.deleted_at IS NULL ORDER BY f.name ASC',
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
    _ensureOwnership(userId);
    return guard('add_favorite', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existing = await txn.query(
          favoriteTable,
          where: 'user_id = ? AND food_item_id = ?',
          whereArgs: <Object?>[userId, foodItemId],
          limit: 1,
        );
        final int now = SyncableDao.nowMs();
        if (existing.isEmpty) {
          final String uuid = SyncableDao.newUuid();
          await txn.insert(
            favoriteTable,
            <String, Object?>{
              'user_id': userId,
              'food_item_id': foodItemId,
              'uuid': uuid,
              'created_at': now,
              'updated_at': now,
              'row_version': SyncableDao.firstRowVersion,
            },
          );
          await SyncableDao.recordCreate(
            txn,
            entity: favoriteTable,
            entityId: uuid,
            userId: userId,
          );
          return;
        }
        final Map<String, Object?> row = existing.first;
        if (row['deleted_at'] != null) {
          // Re-favoriting a soft-deleted row resurrects it and records an
          // UPDATE event (the push re-opens the cloud row via deleted_at=null).
          final int baseVersion = _version(row);
          await txn.update(
            favoriteTable,
            <String, Object?>{
              'deleted_at': null,
              'updated_at': now,
              'row_version': baseVersion + 1,
            },
            where: 'user_id = ? AND food_item_id = ?',
            whereArgs: <Object?>[userId, foodItemId],
          );
          await SyncableDao.recordUpdate(
            txn,
            entity: favoriteTable,
            entityId: row['uuid'] as String,
            userId: userId,
            baseVersion: baseVersion,
          );
        }
        // Already an active favorite: no-op.
      });
    });
  }

  Future<void> removeFavorite(String userId, int foodItemId) {
    _ensureOwnership(userId);
    return guard('remove_favorite', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existing = await txn.query(
          favoriteTable,
          where: 'user_id = ? AND food_item_id = ?',
          whereArgs: <Object?>[userId, foodItemId],
          limit: 1,
        );
        if (existing.isEmpty || existing.first['deleted_at'] != null) return;
        final Map<String, Object?> row = existing.first;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(row);
        await txn.update(
          favoriteTable,
          <String, Object?>{
            'deleted_at': now,
            'updated_at': now,
            'row_version': baseVersion + 1,
          },
          where: 'user_id = ? AND food_item_id = ?',
          whereArgs: <Object?>[userId, foodItemId],
        );
        await SyncableDao.recordDelete(
          txn,
          entity: favoriteTable,
          entityId: row['uuid'] as String,
          userId: userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  /// Favorites are user-owned: the owner must be the authenticated user.
  void _ensureOwnership(String userId) {
    if (!SyncEventRecorder.isCurrentUser(userId)) {
      throw DatabaseException(
        'favorite_ownership_violation',
        code: 'favorite_ownership',
      );
    }
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existing = await txn.query(
          FoodItemModel.table,
          where: 'id = ?',
          whereArgs: <Object?>[id],
          limit: 1,
        );
        if (existing.isEmpty) return;
        final Map<String, Object?> row = existing.first;
        final String? userId = row['user_id'] as String?;
        if (userId == null) {
          // Master row: never soft-delete the shared catalog via sync.
          return;
        }
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(row);
        await txn.update(
          FoodItemModel.table,
          <String, Object?>{
            'deleted_at': now,
            'updated_at': now,
            'row_version': baseVersion + 1,
          },
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        await SyncableDao.recordDelete(
          txn,
          entity: FoodItemModel.table,
          entityId: '$id',
          userId: userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<Set<int>> _favoriteIds(Database db, String userId) async {
    final List<Map<String, Object?>> rows = await db.query(
      favoriteTable,
      columns: <String>['food_item_id'],
      where: 'user_id = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[userId],
    );
    return rows.map((row) => row['food_item_id'] as int).toSet();
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
