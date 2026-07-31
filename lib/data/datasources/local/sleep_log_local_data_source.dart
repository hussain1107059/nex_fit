import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/sleep_log.dart';
import '../../models/sleep_log_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `sleep_log` table.
class SleepLogLocalDataSource extends BaseLocalDataSource {
  SleepLogLocalDataSource({required super.database})
    : super(logName: 'SleepLogLocalDataSource');

  Future<int> insert(SleepLog log) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        SleepLogModel.table,
        SleepLogModel.toMap(log),
      );
    });
  }

  Future<void> update(SleepLog log) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        SleepLogModel.table,
        SleepLogModel.toMap(log),
        where: 'id = ?',
        whereArgs: <Object?>[log.id],
      );
    });
  }

  Future<SleepLog?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        SleepLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return SleepLogModel.fromMap(rows.first);
    });
  }

  Future<List<SleepLog>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        SleepLogModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'sleep_date DESC',
      );
      return rows.map(SleepLogModel.fromMap).toList();
    });
  }

  Future<SleepLog?> getByDate(String userId, DateTime sleepDate) {
    return guard('get_by_date', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        SleepLogModel.table,
        where: 'user_id = ? AND sleep_date = ?',
        whereArgs: <Object?>[userId, sleepDate.millisecondsSinceEpoch],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return SleepLogModel.fromMap(rows.first);
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        SleepLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
