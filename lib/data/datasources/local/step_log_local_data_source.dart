import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/step_log.dart';
import '../../models/step_log_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `step_log` table.
class StepLogLocalDataSource extends BaseLocalDataSource {
  StepLogLocalDataSource({required super.database})
    : super(logName: 'StepLogLocalDataSource');

  Future<int> insert(StepLog log) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        StepLogModel.table,
        StepLogModel.toMap(log),
      );
    });
  }

  Future<void> update(StepLog log) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        StepLogModel.table,
        StepLogModel.toMap(log),
        where: 'id = ?',
        whereArgs: <Object?>[log.id],
      );
    });
  }

  Future<StepLog?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StepLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return StepLogModel.fromMap(rows.first);
    });
  }

  Future<List<StepLog>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StepLogModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'step_date DESC',
      );
      return rows.map(StepLogModel.fromMap).toList();
    });
  }

  Future<StepLog?> getByDate(String userId, DateTime stepDate) {
    return guard('get_by_date', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StepLogModel.table,
        where: 'user_id = ? AND step_date = ?',
        whereArgs: <Object?>[userId, stepDate.millisecondsSinceEpoch],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return StepLogModel.fromMap(rows.first);
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        StepLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
