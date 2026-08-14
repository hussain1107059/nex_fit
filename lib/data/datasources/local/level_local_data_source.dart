import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/level.dart';
import '../../models/level_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `user_level` table (singleton per user).
///
/// Sync-aware (PROMPT 15 Batch 5). The row is keyed by `user_id` (which is also
/// its cloud identity), so `uuid` always equals `user_id`, exactly like
/// `user_profile`. Upsert is a create/update pair so `row_version` and
/// `created_at` survive, and deletes are soft-deletes so the tombstone can be
/// pushed to the cloud.
class LevelLocalDataSource extends BaseLocalDataSource {
  LevelLocalDataSource({required super.database})
      : super(logName: 'LevelLocalDataSource');

  Future<int> insert(LevelProgress levelProgress) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existing = await txn.query(
          LevelModel.table,
          where: 'user_id = ?',
          whereArgs: <Object?>[levelProgress.userId],
          limit: 1,
        );
        if (existing.isNotEmpty) return existing.first['id'] as int;
        return _upsertInTransaction(txn, levelProgress);
      });
    });
  }

  Future<void> upsert(LevelProgress levelProgress) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        await _upsertInTransaction(txn, levelProgress);
      });
    });
  }

  /// Creates or updates the singleton row for [levelProgress.userId] and emits
  /// exactly one outbox event, all inside [txn].
  Future<int> _upsertInTransaction(
    Transaction txn,
    LevelProgress levelProgress,
  ) async {
    final List<Map<String, Object?>> existing = await txn.query(
      LevelModel.table,
      where: 'user_id = ?',
      whereArgs: <Object?>[levelProgress.userId],
      limit: 1,
    );
    final int now = SyncableDao.nowMs();
    if (existing.isNotEmpty) {
      final Map<String, Object?> row = existing.first;
      final int baseVersion = _version(row);
      final Map<String, Object?> values = LevelModel.toMap(levelProgress);
      values.remove('id');
      values['uuid'] = row['uuid'] as String? ?? levelProgress.userId;
      values['created_at'] = row['created_at'];
      values['updated_at'] = now;
      values['row_version'] = baseVersion + 1;
      await txn.update(
        LevelModel.table,
        values,
        where: 'id = ?',
        whereArgs: <Object?>[row['id']],
      );
      await SyncableDao.recordUpdate(
        txn,
        entity: LevelModel.table,
        entityId: levelProgress.userId,
        userId: levelProgress.userId,
        baseVersion: baseVersion,
      );
      return row['id'] as int;
    }
    final Map<String, Object?> values = LevelModel.toMap(levelProgress);
    values['uuid'] = levelProgress.userId;
    values['created_at'] = now;
    values['updated_at'] = now;
    values['row_version'] = SyncableDao.firstRowVersion;
    final int id = await txn.insert(LevelModel.table, values);
    await SyncableDao.recordCreate(
      txn,
      entity: LevelModel.table,
      entityId: levelProgress.userId,
      userId: levelProgress.userId,
    );
    return id;
  }

  Future<LevelProgress?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        LevelModel.table,
        where: 'id = ? AND deleted_at IS NULL',
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
        where: 'user_id = ? AND deleted_at IS NULL',
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
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(LevelModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> existing = await txn.query(
          LevelModel.table,
          where: 'id = ?',
          whereArgs: <Object?>[id],
          limit: 1,
        );
        if (existing.isEmpty) return;
        final Map<String, Object?> row = existing.first;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(row);
        await txn.update(
          LevelModel.table,
          <String, Object?>{
            'deleted_at': now,
            'updated_at': now,
            'row_version': baseVersion + 1,
          },
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        await SyncableDao.recordDelete(
          txn,
          entity: LevelModel.table,
          entityId: row['user_id'] as String,
          userId: row['user_id'] as String,
          baseVersion: baseVersion,
        );
      });
    });
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
