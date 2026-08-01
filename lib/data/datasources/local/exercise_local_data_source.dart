import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/exercise_filter.dart';
import '../../models/exercise_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `exercise` table (built-in + user exercises)
/// and the per-user `exercise_favorite` join table.
class ExerciseLocalDataSource extends BaseLocalDataSource {
  ExerciseLocalDataSource({required super.database})
    : super(logName: 'ExerciseLocalDataSource');

  static const String favoriteTable = 'exercise_favorite';

  Future<int> insert(Exercise exercise) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        ExerciseModel.table,
        ExerciseModel.toMap(exercise),
      );
    });
  }

  Future<void> update(Exercise exercise) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        ExerciseModel.table,
        ExerciseModel.toMap(exercise),
        where: 'id = ?',
        whereArgs: <Object?>[exercise.id],
      );
    });
  }

  Future<Exercise?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseModel.table,
        where: 'id = ?',
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
        where: 'user_id IS NULL',
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
        where: 'user_id = ?',
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
        where: 'user_id IS NULL OR user_id = ?',
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
        '(user_id IS NULL OR user_id = ?)',
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
        'WHERE f.user_id = ? ORDER BY e.name ASC',
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
    return guard('add_favorite', () async {
      final Database db = await dbConnection;
      await db.insert(
        favoriteTable,
        <String, Object?>{
          'user_id': userId,
          'exercise_id': exerciseId,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  Future<void> removeFavorite(String userId, int exerciseId) {
    return guard('remove_favorite', () async {
      final Database db = await dbConnection;
      await db.delete(
        favoriteTable,
        where: 'user_id = ? AND exercise_id = ?',
        whereArgs: <Object?>[userId, exerciseId],
      );
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        ExerciseModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  Future<Set<int>> _favoriteIds(Database db, String userId) async {
    final List<Map<String, Object?>> rows = await db.query(
      favoriteTable,
      columns: <String>['exercise_id'],
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
    );
    return rows.map((Map<String, Object?> row) => row['exercise_id'] as int).toSet();
  }
}
