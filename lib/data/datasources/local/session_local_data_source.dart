import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/app_session.dart';
import '../../models/app_session_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `sessions` table.
class SessionLocalDataSource extends BaseLocalDataSource {
  SessionLocalDataSource({required super.database})
    : super(logName: 'SessionLocalDataSource');

  Future<int> insert(AppSession session) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        AppSessionModel.table,
        AppSessionModel.toMap(session),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> update(AppSession session) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        AppSessionModel.table,
        AppSessionModel.toMap(session),
        where: 'id = ?',
        whereArgs: <Object?>[session.id],
      );
    });
  }

  Future<AppSession?> getActiveByUserId(String userId) {
    return guard('get_active_by_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        AppSessionModel.table,
        where: 'user_id = ? AND is_active = 1',
        whereArgs: <Object?>[userId],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AppSessionModel.fromMap(rows.first);
    });
  }

  Future<List<AppSession>> getByUserId(String userId) {
    return guard('get_by_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        AppSessionModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'created_at DESC',
      );
      return rows.map(AppSessionModel.fromMap).toList();
    });
  }

  Future<void> deactivateByUserId(String userId) {
    return guard('deactivate_by_user', () async {
      final Database db = await dbConnection;
      await db.update(
        AppSessionModel.table,
        <String, Object?>{
          'is_active': 0,
          'last_activity_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'user_id = ? AND is_active = 1',
        whereArgs: <Object?>[userId],
      );
    });
  }

  Future<void> deleteOlderThan(DateTime threshold) {
    return guard('delete_older_than', () async {
      final Database db = await dbConnection;
      await db.delete(
        AppSessionModel.table,
        where: 'is_active = 0 AND created_at < ?',
        whereArgs: <Object?>[threshold.millisecondsSinceEpoch],
      );
    });
  }
}
