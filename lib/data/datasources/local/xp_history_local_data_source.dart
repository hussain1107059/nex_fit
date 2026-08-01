import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/xp_history.dart';
import '../../models/xp_history_model.dart';
import 'base_local_data_source.dart';

class XpHistoryLocalDataSource extends BaseLocalDataSource {
  XpHistoryLocalDataSource({required super.database})
      : super(logName: 'XpHistoryLocalDataSource');

  Future<int> insert(XpHistory xpHistory) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(XpHistoryModel.table, XpHistoryModel.toMap(xpHistory));
    });
  }

  Future<void> update(XpHistory xpHistory) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        XpHistoryModel.table,
        XpHistoryModel.toMap(xpHistory),
        where: 'id = ?',
        whereArgs: <Object?>[xpHistory.id],
      );
    });
  }

  Future<XpHistory?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        XpHistoryModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return XpHistoryModel.fromMap(rows.first);
    });
  }

  Future<List<XpHistory>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        XpHistoryModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'created_at DESC',
      );
      return rows.map(XpHistoryModel.fromMap).toList();
    });
  }

  Future<XpHistory?> getByUserAndSourceAndReason(
    String userId,
    String source,
    String reason,
  ) {
    return guard('get_by_user_and_source_and_reason', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        XpHistoryModel.table,
        where: 'user_id = ? AND source = ? AND reason = ?',
        whereArgs: <Object?>[userId, source, reason],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return XpHistoryModel.fromMap(rows.first);
    });
  }

  Future<int> totalXpForUser(String userId) {
    return guard('total_xp_for_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COALESCE(SUM(xp), 0) AS total FROM ${XpHistoryModel.table} WHERE user_id = ?',
        <Object?>[userId],
      );
      return (rows.first['total'] as num? ?? 0).toInt();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        XpHistoryModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
