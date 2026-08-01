import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/error_log.dart';
import '../../models/error_log_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `error_logs` table.
class ErrorLogLocalDataSource extends BaseLocalDataSource {
  ErrorLogLocalDataSource({required super.database})
    : super(logName: 'ErrorLogLocalDataSource');

  Future<int> insert(ErrorLog log) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(ErrorLogModel.table, ErrorLogModel.toMap(log));
    });
  }

  Future<List<ErrorLog>> getRecent({String? userId, int limit = 50}) {
    return guard('get_recent', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ErrorLogModel.table,
        where: userId == null ? null : 'user_id = ?',
        whereArgs: userId == null ? null : <Object?>[userId],
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return rows.map(ErrorLogModel.fromMap).toList();
    });
  }

  Future<int> count({String? userId}) {
    return guard('count', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM error_logs'
        '${userId == null ? '' : ' WHERE user_id = ?'}',
        userId == null ? null : <Object?>[userId],
      );
      return (rows.first['count'] as num).toInt();
    });
  }

  Future<void> deleteOlderThan(DateTime threshold) {
    return guard('delete_older_than', () async {
      final Database db = await dbConnection;
      await db.delete(
        ErrorLogModel.table,
        where: 'created_at < ?',
        whereArgs: <Object?>[threshold.millisecondsSinceEpoch],
      );
    });
  }
}
