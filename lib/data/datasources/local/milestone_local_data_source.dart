import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/milestone.dart';
import '../../models/milestone_model.dart';
import 'base_local_data_source.dart';

class MilestoneLocalDataSource extends BaseLocalDataSource {
  MilestoneLocalDataSource({required super.database})
      : super(logName: 'MilestoneLocalDataSource');

  Future<int> insert(Milestone milestone) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(MilestoneModel.table, MilestoneModel.toMap(milestone));
    });
  }

  Future<void> update(Milestone milestone) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        MilestoneModel.table,
        MilestoneModel.toMap(milestone),
        where: 'id = ?',
        whereArgs: <Object?>[milestone.id],
      );
    });
  }

  Future<Milestone?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MilestoneModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return MilestoneModel.fromMap(rows.first);
    });
  }

  Future<List<Milestone>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MilestoneModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(MilestoneModel.fromMap).toList();
    });
  }

  Future<List<Milestone>> getByChallengeId(int challengeId) {
    return guard('get_by_challenge_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MilestoneModel.table,
        where: 'challenge_id = ?',
        whereArgs: <Object?>[challengeId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(MilestoneModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        MilestoneModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
