import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/water_log.dart';
import '../../models/water_log_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `water_log` table.
class WaterLogLocalDataSource extends BaseLocalDataSource {
  WaterLogLocalDataSource({required super.database})
    : super(logName: 'WaterLogLocalDataSource');

  Future<int> insert(WaterLog log) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        WaterLogModel.table,
        WaterLogModel.toMap(log),
      );
    });
  }

  Future<void> update(WaterLog log) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        WaterLogModel.table,
        WaterLogModel.toMap(log),
        where: 'id = ?',
        whereArgs: <Object?>[log.id],
      );
    });
  }

  Future<WaterLog?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WaterLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WaterLogModel.fromMap(rows.first);
    });
  }

  Future<List<WaterLog>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WaterLogModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'logged_at DESC',
      );
      return rows.map(WaterLogModel.fromMap).toList();
    });
  }

  Future<List<WaterLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return guard('get_by_date_range', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WaterLogModel.table,
        where: 'user_id = ? AND logged_at >= ? AND logged_at < ?',
        whereArgs: <Object?>[
          userId,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'logged_at DESC',
      );
      return rows.map(WaterLogModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        WaterLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
