import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/exercise_filter.dart';
import '../../models/exercise_model.dart';
import '../../services/sync/sync_event_recorder.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `exercise` table (built-in + user exercises)
/// and the per-user `exercise_favorite` join table.
class ExerciseLocalDataSource extends BaseLocalDataSource {
  ExerciseLocalDataSource({required super.database})
    : super(logName: 'ExerciseLocalDataSource');

  static const String favoriteTable = 'exercise_favorite';

  Future<int> insert(Exercise exercise) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = ExerciseModel.toMap(exercise);
        if (exercise.userId != null) {
          // Custom (user-owned) rows enter the outbox with a fresh uuid.
          values['uuid'] = SyncableDao.newUuid();
          values['created_at'] = now;
          values['updated_at'] = now;
          values['row_version'] = SyncableDao.firstRowVersion;
        }
        final int id = await txn.insert(ExerciseModel.table, values);
        if (exercise.userId != null) {
          await SyncableDao.recordCreate(
            txn,
            entity: ExerciseModel.table,
            entityId: '$id',
            userId: exercise.userId!,
          );
        }
        return id;
      });
    });
  }

  Future<void> update(Exercise exercise) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        if (exercise.userId == null) {
          // Master row: local-only catalog update, no outbox event.
          await txn.update(
            ExerciseModel.table,
            ExerciseModel.toMap(exercise),
            where: 'id = ?',
            whereArgs: <Object?>[exercise.id],
          );
          return;
        }
        final List<Map<String, Object?>> existing = await txn.query(
          ExerciseModel.table,
          where: 'id = ?',
          whereArgs: <Object?>[exercise.id],
          limit: 1,
        );
        if (existing.isEmpty) return;
        final Map<String, Object?> row = existing.first;
        final int baseVersion = _version(row);
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = ExerciseModel.toMap(exercise);
        values['uuid'] = row['uuid'] as String? ?? SyncableDao.newUuid();
        values['created_at'] = row['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          ExerciseModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[exercise.id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: ExerciseModel.table,
          entityId: '${exercise.id}',
          userId: exercise.userId!,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<Exercise?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ExerciseModel.fromMap(rows.first);
    });
  }

  Future<List<Exercise>> getBuiltIn() {
    return guard('get_built_in', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseModel.table,
        where: 'user_id IS NULL AND deleted_at IS NULL',
        orderBy: 'name ASC',
      );
      return rows.map(ExerciseModel.fromMap).toList();
    });
  }

  Future<List<Exercise>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'name ASC',
      );
      return rows.map(ExerciseModel.fromMap).toList();
    });
  }

  /// Full catalog visible to [userId]: built-in exercises plus the user's own.
  Future<List<Exercise>> getAll(String userId) {
    return guard('get_all', () async {
      final Database db = await dbConnection;
      final Set<int> favorites = await _favoriteIds(db, userId);
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseModel.table,
        where: '(user_id IS NULL AND deleted_at IS NULL) '
            'OR (user_id = ? AND deleted_at IS NULL)',
        whereArgs: <Object?>[userId],
        orderBy: 'name ASC',
      );
      return rows
          .map((Map<String, Object?> row) {
            final Exercise exercise = ExerciseModel.fromMap(row);
            return exercise.copyWith(
              isFavorite: exercise.id != null &&
                  favorites.contains(exercise.id),
            );
          })
          .toList();
    });
  }

  /// Applies [filter] over the catalog and annotates favourite flags.
  Future<List<Exercise>> search(
    ExerciseFilter filter,
    String userId,
  ) {
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
          'id IN (SELECT exercise_id FROM $favoriteTable WHERE user_id = ?)',
        );
        args.add(userId);
      }
      if (filter.category != null) {
        where.add('category = ?');
        args.add(filter.category!.name);
      }
      if (filter.difficulty != null) {
        where.add('difficulty = ?');
        args.add(filter.difficulty!.name);
      }
      if (filter.equipment != null && filter.equipment!.isNotEmpty) {
        where.add('equipment = ?');
        args.add(filter.equipment);
      }
      if (query.isNotEmpty) {
        where.add('LOWER(name) LIKE ?');
        args.add('%$query%');
      }

      final List<Map<String, Object?>> rows = await db.query(
        ExerciseModel.table,
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'name ASC',
      );
      return rows
          .map((Map<String, Object?> row) {
            final Exercise exercise = ExerciseModel.fromMap(row);
            return exercise.copyWith(
              isFavorite: exercise.id != null &&
                  favorites.contains(exercise.id),
            );
          })
          .toList();
    });
  }

  /// Exercises favourited by [userId], annotated with the flag set.
  Future<List<Exercise>> getFavorites(String userId) {
    return guard('get_favorites', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT e.* FROM ${ExerciseModel.table} e '
        'INNER JOIN $favoriteTable f ON f.exercise_id = e.id '
        'WHERE f.user_id = ? AND f.deleted_at IS NULL '
        'AND e.deleted_at IS NULL ORDER BY e.name ASC',
        <Object?>[userId],
      );
      return rows
          .map((Map<String, Object?> row) {
            final Exercise exercise = ExerciseModel.fromMap(row);
            return exercise.copyWith(isFavorite: true);
          })
          .toList();
    });
  }

  Future<Set<int>> getFavoriteIds(String userId) {
    return guard('get_favorite_ids', () async {
      final Database db = await dbConnection;
      return _favoriteIds(db, userId);
    });
  }

  Future<void> addFavorite(String userId, int exerciseId) {
    _ensureOwnership(userId);
    return guard('add_favorite', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existing = await txn.query(
          favoriteTable,
          where: 'user_id = ? AND exercise_id = ?',
          whereArgs: <Object?>[userId, exerciseId],
          limit: 1,
        );
        final int now = SyncableDao.nowMs();
        if (existing.isEmpty) {
          final String uuid = SyncableDao.newUuid();
          await txn.insert(
            favoriteTable,
            <String, Object?>{
              'user_id': userId,
              'exercise_id': exerciseId,
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
            where: 'user_id = ? AND exercise_id = ?',
            whereArgs: <Object?>[userId, exerciseId],
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

  Future<void> removeFavorite(String userId, int exerciseId) {
    _ensureOwnership(userId);
    return guard('remove_favorite', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existing = await txn.query(
          favoriteTable,
          where: 'user_id = ? AND exercise_id = ?',
          whereArgs: <Object?>[userId, exerciseId],
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
          where: 'user_id = ? AND exercise_id = ?',
          whereArgs: <Object?>[userId, exerciseId],
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
          ExerciseModel.table,
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
          ExerciseModel.table,
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
          entity: ExerciseModel.table,
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
      columns: <String>['exercise_id'],
      where: 'user_id = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[userId],
    );
    return rows.map((Map<String, Object?> row) => row['exercise_id'] as int).toSet();
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
