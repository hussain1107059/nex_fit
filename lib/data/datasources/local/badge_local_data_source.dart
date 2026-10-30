import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/badge.dart';
import '../../models/badge_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `badge` table.
///
/// Sync-aware (PROMPT 34 Batch 6): every mutation records its outbox event in
/// the same transaction, maintains the sync columns (`uuid`, `created_at`,
/// `updated_at`, `row_version`) and soft-deletes so a queued DELETE is never
/// lost. `badge_def_id` is resolved from the local master catalog by
/// `badge_type`; the push transport resolves its uuid to the cloud `badge_id`
/// and defers the push (retryable) until the catalog row exists.
class BadgeLocalDataSource extends BaseLocalDataSource {
  BadgeLocalDataSource({required super.database})
    : super(logName: 'BadgeLocalDataSource');

  static const String _defTable = 'badge_def';

  Future<int> insert(Badge badge) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) => _insertInTxn(txn, badge));
    });
  }

  Future<void> insertAll(List<Badge> badges) {
    return guard('insert_all', () async {
      if (badges.isEmpty) return;
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        for (final Badge badge in badges) {
          await _insertInTxn(txn, badge);
        }
      });
    });
  }

  Future<void> updateAll(List<Badge> badges) {
    return guard('update_all', () async {
      if (badges.isEmpty) return;
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        for (final Badge badge in badges) {
          await _updateInTxn(txn, badge);
        }
      });
    });
  }

  Future<void> update(Badge badge) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) => _updateInTxn(txn, badge));
    });
  }

  Future<Badge?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BadgeModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return BadgeModel.fromMap(rows.first);
    });
  }

  Future<List<Badge>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BadgeModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'badge_type ASC, level ASC',
      );
      return rows.map(BadgeModel.fromMap).toList();
    });
  }

  Future<Badge?> getByUserAndType(String userId, String badgeType) {
    return guard('get_by_user_and_type', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BadgeModel.table,
        where: 'user_id = ? AND badge_type = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId, badgeType],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return BadgeModel.fromMap(rows.first);
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
          BadgeModel.table,
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
          entity: BadgeModel.table,
          entityId: '$id',
          userId: existing['user_id'] as String,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<int> _insertInTxn(Transaction txn, Badge badge) async {
    // `badge` is unique on (user_id, badge_type) and gamification recomputes
    // the whole set after every session; keep the old ignore-duplicates
    // behaviour instead of throwing on the second insert.
    final Map<String, Object?>? existing = await _findByUserAndType(
      txn,
      badge.userId,
      badge.badgeType,
    );
    if (existing != null) {
      final int existingId = existing['id'] as int;
      if (existing['deleted_at'] != null) {
        await _updateInTxn(txn, badge.copyWith(id: existingId));
      }
      return existingId;
    }
    final int now = SyncableDao.nowMs();
    final Map<String, Object?> values = BadgeModel.toMap(badge);
    values['uuid'] = SyncableDao.newUuid();
    values['created_at'] = values['created_at'] ?? now;
    values['updated_at'] = now;
    values['row_version'] = SyncableDao.firstRowVersion;
    values['badge_def_id'] = await _resolveDefId(txn, values['badge_type']);
    final int id = await txn.insert(BadgeModel.table, values);
    await SyncableDao.recordCreate(
      txn,
      entity: BadgeModel.table,
      entityId: '$id',
      userId: badge.userId,
    );
    return id;
  }

  Future<void> _updateInTxn(Transaction txn, Badge badge) async {
    final Map<String, Object?>? existing = await _findRow(txn, badge.id);
    if (existing == null) return;
    final int now = SyncableDao.nowMs();
    final int baseVersion = _version(existing);
    final Map<String, Object?> values = BadgeModel.toMap(badge);
    values['id'] = existing['id'];
    values['uuid'] = existing['uuid'] as String? ?? SyncableDao.newUuid();
    values['created_at'] = existing['created_at'] ?? values['created_at'];
    values['updated_at'] = now;
    values['row_version'] = baseVersion + 1;
    values['badge_def_id'] =
        await _resolveDefId(txn, values['badge_type']) ??
        existing['badge_def_id'];
    // Clear a remotely applied tombstone when the badge is earned again.
    values['deleted_at'] = null;
    // Gamification recomputes every badge after each session; do not enqueue a
    // redundant event when nothing syncable changed.
    if (_sameSyncedValues(existing, values)) return;
    await txn.update(
      BadgeModel.table,
      values,
      where: 'id = ?',
      whereArgs: <Object?>[existing['id']],
    );
    await SyncableDao.recordUpdate(
      txn,
      entity: BadgeModel.table,
      entityId: '${existing['id']}',
      userId: existing['user_id'] as String,
      baseVersion: baseVersion,
    );
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      BadgeModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> _findByUserAndType(
    Transaction txn,
    String userId,
    String badgeType,
  ) async {
    final List<Map<String, Object?>> rows = await txn.query(
      BadgeModel.table,
      where: 'user_id = ? AND badge_type = ?',
      whereArgs: <Object?>[userId, badgeType],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int?> _resolveDefId(Transaction txn, Object? badgeType) async {
    if (badgeType is! String || badgeType.isEmpty) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      _defTable,
      columns: const <String>['id'],
      where: 'badge_type = ?',
      whereArgs: <Object?>[badgeType],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int?;
  }

  static bool _sameSyncedValues(
    Map<String, Object?> existing,
    Map<String, Object?> values,
  ) {
    if (existing['deleted_at'] != null) return false;
    const List<String> columns = <String>[
      'badge_def_id',
      'level',
      'progress',
      'target',
      'is_earned',
      'earned_at',
    ];
    for (final String column in columns) {
      if (existing[column] != values[column]) return false;
    }
    return true;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
