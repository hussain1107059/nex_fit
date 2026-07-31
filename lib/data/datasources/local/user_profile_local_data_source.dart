import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/user_profile.dart';
import '../../models/user_profile_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `user_profile` table.
class UserProfileLocalDataSource extends BaseLocalDataSource {
  UserProfileLocalDataSource({required super.database})
    : super(logName: 'UserProfileLocalDataSource');

  Future<int> upsert(UserProfile profile) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      return db.insert(
        UserProfileModel.table,
        UserProfileModel.toMap(profile),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<UserProfile?> getById(String userId) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        UserProfileModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return UserProfileModel.fromMap(rows.first);
    });
  }

  Future<void> delete(String userId) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        UserProfileModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
      );
    });
  }
}
