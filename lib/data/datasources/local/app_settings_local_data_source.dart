import 'dart:async';

import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/security_enums.dart';
import '../../models/app_settings_model.dart';
import '../../services/sync/sync_event_recorder.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `app_settings` table (one row per user).
class AppSettingsLocalDataSource extends BaseLocalDataSource {
  AppSettingsLocalDataSource({required super.database})
    : super(logName: 'AppSettingsLocalDataSource');

  Future<int> upsert(AppSettings settings) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      final int id = await db.insert(
        AppSettingsModel.table,
        AppSettingsModel.toMap(settings),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      unawaited(
        SyncEventRecorder.record(
          entity: AppSettingsModel.table,
          entityId: settings.userId,
          operation: SyncOperation.update,
          userId: settings.userId,
        ),
      );
      return id;
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
