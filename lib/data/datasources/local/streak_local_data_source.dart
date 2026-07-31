import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/streak.dart';
import '../../models/streak_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `streak` table (one row per user + type).
class StreakLocalDataSource extends BaseLocalDataSource {
  StreakLocalDataSource({required super.database})
    : super(logName: 'StreakLocalDataSource');

  Future<int> upsert(Streak streak) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      return db.insert(
        StreakModel.table,
        StreakModel.toMap(streak),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<Streak?> getByUserAndType(String userId, String streakType) {
    return guard('get_by_user_and_type', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StreakModel.table,
        where: 'user_id = ? AND streak_type = ?',
        whereArgs: <Object?>[userId, streakType],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return StreakModel.fromMap(rows.first);
    });
  }

  Future<List<Streak>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StreakModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'streak_type ASC',
      );
      return rows.map(StreakModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        StreakModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
