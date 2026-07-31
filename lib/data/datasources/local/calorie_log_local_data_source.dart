import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/calorie_log.dart';
import '../../models/calorie_log_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `calorie_log` table.
class CalorieLogLocalDataSource extends BaseLocalDataSource {
  CalorieLogLocalDataSource({required super.database})
    : super(logName: 'CalorieLogLocalDataSource');

  Future<int> insert(CalorieLog log) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        CalorieLogModel.table,
        CalorieLogModel.toMap(log),
      );
    });
  }

  Future<void> update(CalorieLog log) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        CalorieLogModel.table,
        CalorieLogModel.toMap(log),
        where: 'id = ?',
        whereArgs: <Object?>[log.id],
      );
    });
  }

  Future<CalorieLog?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        CalorieLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return CalorieLogModel.fromMap(rows.first);
    });
  }

  Future<List<CalorieLog>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        CalorieLogModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'logged_at DESC',
      );
      return rows.map(CalorieLogModel.fromMap).toList();
    });
  }

  Future<List<CalorieLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return guard('get_by_date_range', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        CalorieLogModel.table,
        where: 'user_id = ? AND logged_at >= ? AND logged_at < ?',
        whereArgs: <Object?>[
          userId,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'logged_at DESC',
      );
      return rows.map(CalorieLogModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        CalorieLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
