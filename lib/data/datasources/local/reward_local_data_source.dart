import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/reward.dart';
import '../../models/reward_model.dart';
import 'base_local_data_source.dart';

class RewardLocalDataSource extends BaseLocalDataSource {
  RewardLocalDataSource({required super.database})
      : super(logName: 'RewardLocalDataSource');

  Future<int> insert(Reward reward) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(RewardModel.table, RewardModel.toMap(reward));
    });
  }

  Future<void> update(Reward reward) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        RewardModel.table,
        RewardModel.toMap(reward),
        where: 'id = ?',
        whereArgs: <Object?>[reward.id],
      );
    });
  }

  Future<Reward?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        RewardModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return RewardModel.fromMap(rows.first);
    });
  }

  Future<List<Reward>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        RewardModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(RewardModel.fromMap).toList();
    });
  }

  Future<Reward?> getByUserAndType(String userId, String type, String title) {
    return guard('get_by_user_and_type', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        RewardModel.table,
        where: 'user_id = ? AND type = ? AND title = ?',
        whereArgs: <Object?>[userId, type, title],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return RewardModel.fromMap(rows.first);
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        RewardModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
