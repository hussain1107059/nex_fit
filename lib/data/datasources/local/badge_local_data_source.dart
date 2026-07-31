import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/badge.dart';
import '../../models/badge_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `badge` table.
class BadgeLocalDataSource extends BaseLocalDataSource {
  BadgeLocalDataSource({required super.database})
    : super(logName: 'BadgeLocalDataSource');

  Future<int> insert(Badge badge) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        BadgeModel.table,
        BadgeModel.toMap(badge),
      );
    });
  }

  Future<void> update(Badge badge) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        BadgeModel.table,
        BadgeModel.toMap(badge),
        where: 'id = ?',
        whereArgs: <Object?>[badge.id],
      );
    });
  }

  Future<Badge?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BadgeModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return BadgeModel.fromMap(rows.first);
    });
  }

  Future<List<Badge>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BadgeModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'badge_type ASC, level ASC',
      );
      return rows.map(BadgeModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        BadgeModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
