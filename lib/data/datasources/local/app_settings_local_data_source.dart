import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/app_settings.dart';
import '../../models/app_settings_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `app_settings` table (one row per user).
class AppSettingsLocalDataSource extends BaseLocalDataSource {
  AppSettingsLocalDataSource({required super.database})
    : super(logName: 'AppSettingsLocalDataSource');

  Future<int> upsert(AppSettings settings) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      return db.insert(
        AppSettingsModel.table,
        AppSettingsModel.toMap(settings),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<AppSettings?> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        AppSettingsModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AppSettingsModel.fromMap(rows.first);
    });
  }

  Future<void> delete(String userId) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        AppSettingsModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
      );
    });
  }
}
