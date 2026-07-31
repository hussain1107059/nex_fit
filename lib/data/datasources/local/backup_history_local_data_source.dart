import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/backup_history.dart';
import '../../models/backup_history_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `backup_history` table.
class BackupHistoryLocalDataSource extends BaseLocalDataSource {
  BackupHistoryLocalDataSource({required super.database})
    : super(logName: 'BackupHistoryLocalDataSource');

  Future<int> insert(BackupHistory history) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        BackupHistoryModel.table,
        BackupHistoryModel.toMap(history),
      );
    });
  }

  Future<BackupHistory?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BackupHistoryModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return BackupHistoryModel.fromMap(rows.first);
    });
  }

  Future<List<BackupHistory>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BackupHistoryModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'created_at DESC',
      );
      return rows.map(BackupHistoryModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        BackupHistoryModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
