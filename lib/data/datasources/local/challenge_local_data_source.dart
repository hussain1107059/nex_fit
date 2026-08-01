import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/challenge.dart';
import '../../models/challenge_model.dart';
import 'base_local_data_source.dart';

class ChallengeLocalDataSource extends BaseLocalDataSource {
  ChallengeLocalDataSource({required super.database})
      : super(logName: 'ChallengeLocalDataSource');

  Future<int> insert(Challenge challenge) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(ChallengeModel.table, ChallengeModel.toMap(challenge));
    });
  }

  Future<void> update(Challenge challenge) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        ChallengeModel.table,
        ChallengeModel.toMap(challenge),
        where: 'id = ?',
        whereArgs: <Object?>[challenge.id],
      );
    });
  }

  Future<Challenge?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ChallengeModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ChallengeModel.fromMap(rows.first);
    });
  }

  Future<List<Challenge>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ChallengeModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(ChallengeModel.fromMap).toList();
    });
  }

  Future<Challenge?> getByUserAndType(String userId, String type) {
    return guard('get_by_user_and_type', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ChallengeModel.table,
        where: 'user_id = ? AND type = ?',
        whereArgs: <Object?>[userId, type],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ChallengeModel.fromMap(rows.first);
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        ChallengeModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
