import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/level.dart';
import '../../models/level_model.dart';
import 'base_local_data_source.dart';

class LevelLocalDataSource extends BaseLocalDataSource {
  LevelLocalDataSource({required super.database})
      : super(logName: 'LevelLocalDataSource');

  Future<int> insert(LevelProgress levelProgress) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(LevelModel.table, LevelModel.toMap(levelProgress));
    });
  }

  Future<void> upsert(LevelProgress levelProgress) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      final int? id = levelProgress.id;
      if (id == null) {
        await db.insert(LevelModel.table, LevelModel.toMap(levelProgress));
      } else {
        await db.update(
          LevelModel.table,
          LevelModel.toMap(levelProgress),
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
      }
    });
  }

  Future<LevelProgress?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        LevelModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return LevelModel.fromMap(rows.first);
    });
  }

  Future<LevelProgress?> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        LevelModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return LevelModel.fromMap(rows.first);
    });
  }

  Future<List<LevelProgress>> getHistoryByUserId(String userId) {
    return guard('get_history_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        LevelModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(LevelModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        LevelModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
