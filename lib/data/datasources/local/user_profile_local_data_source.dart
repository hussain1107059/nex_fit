import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/user_profile.dart';
import '../../models/user_profile_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `user_profile` table (singleton per user).
///
/// Sync-aware (PROMPT 11 Batch 1). The profile is keyed by `user_id` (which is
/// also its cloud `profiles.id`, the auth uid), so the row's `uuid` always
/// equals `user_id`. Upsert becomes a create/update pair so `row_version` and
/// `created_at` survive, and deletes are soft-deletes (the cloud has no
/// `deleted_at` on `profiles`, so the delete event is a transport no-op, but
/// the local row is never physically destroyed).
class UserProfileLocalDataSource extends BaseLocalDataSource {
  UserProfileLocalDataSource({required super.database})
    : super(logName: 'UserProfileLocalDataSource');

  Future<int> upsert(UserProfile profile) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existingRows = await txn.query(
          UserProfileModel.table,
          where: 'user_id = ?',
          whereArgs: <Object?>[profile.userId],
          limit: 1,
        );
        final int now = SyncableDao.nowMs();
        if (existingRows.isNotEmpty) {
          final Map<String, Object?> existing = existingRows.first;
          final int baseVersion = _version(existing);
          final Map<String, Object?> values = UserProfileModel.toMap(profile);
          values['uuid'] = existing['uuid'] as String? ?? profile.userId;
          values['created_at'] = existing['created_at'];
          values['updated_at'] = now;
          values['row_version'] = baseVersion + 1;
          // Partial profile writes (photo change, weight/water goal, hydration)
          // build a UserProfile without a name. Never let them erase the name
          // that was mirrored from the `users` table / pulled from the cloud.
          if (values['display_name'] == null) {
            values['display_name'] = existing['display_name'];
          }
          await txn.update(
            UserProfileModel.table,
            values,
            where: 'user_id = ?',
            whereArgs: <Object?>[profile.userId],
          );
          await SyncableDao.recordUpdate(
            txn,
            entity: UserProfileModel.table,
            entityId: profile.userId,
            userId: profile.userId,
            baseVersion: baseVersion,
          );
          return 1;
        }
        final Map<String, Object?> values = UserProfileModel.toMap(profile);
        values['uuid'] = profile.userId;
        values['created_at'] = now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(UserProfileModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: UserProfileModel.table,
          entityId: profile.userId,
          userId: profile.userId,
        );
        return id;
      });
    });
  }

  Future<UserProfile?> getById(String userId) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        UserProfileModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
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
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existingRows = await txn.query(
          UserProfileModel.table,
          where: 'user_id = ?',
          whereArgs: <Object?>[userId],
          limit: 1,
        );
        if (existingRows.isEmpty) return;
        final Map<String, Object?> existing = existingRows.first;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await txn.update(
          UserProfileModel.table,
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
          entity: UserProfileModel.table,
          entityId: userId,
          userId: userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  /// Mirrors a display-name change onto the sync-synced singleton profile so
  /// the outbox pushes it to the cloud `profiles.display_name`. The local
  /// `users` table remains the app's source of truth for the name; this row is
  /// the sync carrier. A missing profile row is created (CREATE event); an
  /// existing one is patched in place (UPDATE event with its base version).
  Future<void> updateDisplayName(String userId, String? displayName) {
    return guard('update_display_name', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existingRows = await txn.query(
          UserProfileModel.table,
          where: 'user_id = ?',
          whereArgs: <Object?>[userId],
          limit: 1,
        );
        final int now = SyncableDao.nowMs();
        if (existingRows.isNotEmpty) {
          final Map<String, Object?> existing = existingRows.first;
          // Already mirrored (e.g. the saveProfile write in updateProfile):
          // do not bump the version or enqueue a duplicate event.
          if (existing['display_name'] == displayName) return;
          final int baseVersion = _version(existing);
          await txn.update(
            UserProfileModel.table,
            <String, Object?>{
              'display_name': displayName,
              'updated_at': now,
              'row_version': baseVersion + 1,
            },
            where: 'user_id = ?',
            whereArgs: <Object?>[userId],
          );
          await SyncableDao.recordUpdate(
            txn,
            entity: UserProfileModel.table,
            entityId: userId,
            userId: userId,
            baseVersion: baseVersion,
          );
          return;
        }
        await txn.insert(UserProfileModel.table, <String, Object?>{
          'user_id': userId,
          'uuid': userId,
          'display_name': displayName,
          'created_at': now,
          'updated_at': now,
          'row_version': SyncableDao.firstRowVersion,
        });
        await SyncableDao.recordCreate(
          txn,
          entity: UserProfileModel.table,
          entityId: userId,
          userId: userId,
        );
      });
    });
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
