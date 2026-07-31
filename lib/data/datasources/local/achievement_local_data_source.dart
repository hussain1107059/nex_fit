import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/achievement.dart';
import '../../models/achievement_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `achievement` table.
class AchievementLocalDataSource extends BaseLocalDataSource {
  AchievementLocalDataSource({required super.database})
    : super(logName: 'AchievementLocalDataSource');

  Future<int> insert(Achievement achievement) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        AchievementModel.table,
        AchievementModel.toMap(achievement),
      );
    });
  }

  Future<void> update(Achievement achievement) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        AchievementModel.table,
        AchievementModel.toMap(achievement),
        where: 'id = ?',
        whereArgs: <Object?>[achievement.id],
      );
    });
  }

  Future<Achievement?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        AchievementModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AchievementModel.fromMap(rows.first);
    });
  }

  Future<List<Achievement>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        AchievementModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'created_at DESC',
      );
      return rows.map(AchievementModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        AchievementModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
