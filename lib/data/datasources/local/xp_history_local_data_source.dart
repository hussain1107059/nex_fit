import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/xp_history.dart';
import '../../models/xp_history_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `xp_history` table.
///
/// Sync-aware (PROMPT 14 Batch 4): the XP ledger is source-of-truth user data.
/// Every mutation runs inside a transaction with its outbox event; reads filter
/// out soft-deleted rows; delete soft-deletes instead of destroying. The sync
/// mapping intentionally omits the derived `total_xp` running total and the
/// cloud-`jsonb` `metadata` column (see the registry) — the local table still
/// stores both, but they are never pushed.
class XpHistoryLocalDataSource extends BaseLocalDataSource {
  XpHistoryLocalDataSource({required super.database})
      : super(logName: 'XpHistoryLocalDataSource');

  Future<int> insert(XpHistory xpHistory) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = XpHistoryModel.toMap(xpHistory);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(XpHistoryModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: XpHistoryModel.table,
          entityId: '$id',
          userId: xpHistory.userId,
        );
        return id;
      });
    });
  }

  Future<void> update(XpHistory xpHistory) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, xpHistory.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = XpHistoryModel.toMap(xpHistory);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String;
        values['created_at'] = values['created_at'] ?? existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          XpHistoryModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[xpHistory.id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: XpHistoryModel.table,
          entityId: '${xpHistory.id}',
          userId: xpHistory.userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<XpHistory?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        XpHistoryModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return XpHistoryModel.fromMap(rows.first);
    });
  }

  Future<List<XpHistory>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        XpHistoryModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'created_at DESC',
      );
      return rows.map(XpHistoryModel.fromMap).toList();
    });
  }

  Future<XpHistory?> getByUserAndSourceAndReason(
    String userId,
    String source,
    String reason,
  ) {
    return guard('get_by_user_and_source_and_reason', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        XpHistoryModel.table,
        where:
            'user_id = ? AND source = ? AND reason = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId, source, reason],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return XpHistoryModel.fromMap(rows.first);
    });
  }

  Future<int> totalXpForUser(String userId) {
    return guard('total_xp_for_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COALESCE(SUM(xp), 0) AS total FROM ${XpHistoryModel.table} '
        'WHERE user_id = ? AND deleted_at IS NULL',
        <Object?>[userId],
      );
      return (rows.first['total'] as num? ?? 0).toInt();
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
          XpHistoryModel.table,
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
          entity: XpHistoryModel.table,
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
      XpHistoryModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
