import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/app_settings.dart';
import '../../models/app_settings_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `app_settings` table (one row per user).
///
/// Sync-aware (PROMPT 11 Batch 1). The settings row is a per-user singleton
/// whose cloud identity (`uuid`) is the `user_id`. Upsert is a create/update
/// pair that preserves `uuid`/`created_at` and bumps `row_version`, and
/// deletes are soft-deletes.
class AppSettingsLocalDataSource extends BaseLocalDataSource {
  AppSettingsLocalDataSource({required super.database})
    : super(logName: 'AppSettingsLocalDataSource');

  Future<int> upsert(AppSettings settings, {bool trackSync = true}) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existingRows = await txn.query(
          AppSettingsModel.table,
          where: 'user_id = ?',
          whereArgs: <Object?>[settings.userId],
          limit: 1,
        );
        final int now = SyncableDao.nowMs();
        if (existingRows.isNotEmpty) {
          final Map<String, Object?> existing = existingRows.first;
          final int baseVersion = _version(existing);
          final Map<String, Object?> values = AppSettingsModel.toMap(settings);
          values['id'] = existing['id'];
          values['uuid'] = existing['uuid'] as String? ?? settings.userId;
          values['created_at'] = existing['created_at'];
          values['updated_at'] = now;
          // Device-local telemetry writes (lastSyncAt / lastActiveAt) must not
          // bump row_version or enqueue an outbox event, or every sync run
          // re-stamps the timestamp and the queue can never drain.
          if (trackSync) {
            values['row_version'] = baseVersion + 1;
          } else {
            values['row_version'] = existing['row_version'];
          }
          await txn.update(
            AppSettingsModel.table,
            values,
            where: 'user_id = ?',
            whereArgs: <Object?>[settings.userId],
          );
          if (trackSync) {
            await SyncableDao.recordUpdate(
              txn,
              entity: AppSettingsModel.table,
              entityId: settings.userId,
              userId: settings.userId,
              baseVersion: baseVersion,
            );
          }
          return 1;
        }
        final Map<String, Object?> values = AppSettingsModel.toMap(settings);
        values['uuid'] = settings.userId;
        values['created_at'] = now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(AppSettingsModel.table, values);
        // A brand-new row must always be announced so the server ever learns
        // of it, even when this particular write is device-local telemetry.
        await SyncableDao.recordCreate(
          txn,
          entity: AppSettingsModel.table,
          entityId: settings.userId,
          userId: settings.userId,
        );
        return id;
      });
    });
  }

  Future<AppSettings?> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        AppSettingsModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
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
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existingRows = await txn.query(
          AppSettingsModel.table,
          where: 'user_id = ?',
          whereArgs: <Object?>[userId],
          limit: 1,
        );
        if (existingRows.isEmpty) return;
        final Map<String, Object?> existing = existingRows.first;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await txn.update(
          AppSettingsModel.table,
          <String, Object?>{
            'deleted_at': now,
            'updated_at': now,
            'row_version': baseVersion + 1,
          },
          where: 'user_id = ?',
          whereArgs: <Object?>[userId],
        );
        await SyncableDao.recordDelete(
          txn,
          entity: AppSettingsModel.table,
          entityId: userId,
          userId: userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}