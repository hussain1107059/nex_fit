import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/bmi_log.dart';
import '../../models/bmi_log_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `bmi_log` table.
class BmiLogLocalDataSource extends BaseLocalDataSource {
  BmiLogLocalDataSource({required super.database})
    : super(logName: 'BmiLogLocalDataSource');

  Future<int> insert(BmiLog log) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        BmiLogModel.table,
        BmiLogModel.toMap(log),
      );
    });
  }

  Future<BmiLog?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BmiLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return BmiLogModel.fromMap(rows.first);
    });
  }

  Future<List<BmiLog>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BmiLogModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'logged_at DESC',
      );
      return rows.map(BmiLogModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        BmiLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
