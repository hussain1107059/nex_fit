import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/reward.dart';
import '../../models/reward_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `reward` table.
///
/// Sync-aware (PROMPT 14 Batch 4): reward claims are source-of-truth user
/// data. Every mutation runs inside a transaction with its outbox event; reads
/// filter out soft-deleted rows; delete soft-deletes instead of destroying.
class RewardLocalDataSource extends BaseLocalDataSource {
  RewardLocalDataSource({required super.database})
    : super(logName: 'RewardLocalDataSource');

  Future<int> insert(Reward reward) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = RewardModel.toMap(reward);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(RewardModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: RewardModel.table,
          entityId: '$id',
          userId: reward.userId,
        );
        return id;
      });
    });
  }

  Future<void> update(Reward reward) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, reward.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = RewardModel.toMap(reward);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String;
        values['created_at'] = values['created_at'] ?? existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          RewardModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[reward.id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: RewardModel.table,
          entityId: '${reward.id}',
          userId: reward.userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<Reward?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        RewardModel.table,
        where: 'id = ? AND deleted_at IS NULL',
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
        where: 'user_id = ? AND deleted_at IS NULL',
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
        where: 'user_id = ? AND type = ? AND title = ? AND deleted_at IS NULL',
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
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await txn.update(
          RewardModel.table,
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
          entity: RewardModel.table,
          entityId: '$id',
          userId: existing['user_id'] as String,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      RewardModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
