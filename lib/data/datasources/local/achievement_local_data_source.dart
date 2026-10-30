import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/achievement.dart';
import '../../models/achievement_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `achievement` table.
///
/// Sync-aware (PROMPT 34 Batch 6): every mutation runs inside a transaction
/// with its outbox event; sync columns are maintained by the DAO. Deletes are
/// soft-deletes (tombstones) so queued DELETE events are never lost.
/// `achievement_def_id` is resolved from the local master catalog by
/// `achievement_type`; the push transport maps it to the cloud
/// `achievement_id` and defers (retryable) until the catalog uuid exists.
class AchievementLocalDataSource extends BaseLocalDataSource {
  AchievementLocalDataSource({required super.database})
    : super(logName: 'AchievementLocalDataSource');

  static const String _defTable = 'achievement_def';

  Future<int> insert(Achievement achievement) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction(
        (Transaction txn) => _insertInTxn(txn, achievement),
      );
    });
  }

  Future<void> insertAll(List<Achievement> achievements) {
    return guard('insert_all', () async {
      if (achievements.isEmpty) return;
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        for (final Achievement achievement in achievements) {
          await _insertInTxn(txn, achievement);
        }
      });
    });
  }

  Future<void> updateAll(List<Achievement> achievements) {
    return guard('update_all', () async {
      if (achievements.isEmpty) return;
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        for (final Achievement achievement in achievements) {
          await _updateInTxn(txn, achievement);
        }
      });
    });
  }

  Future<void> update(Achievement achievement) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) => _updateInTxn(txn, achievement));
    });
  }

  Future<Achievement?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        AchievementModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AchievementModel.fromMap(rows.first);
    });
  }

  Future<List<Achievement>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        AchievementModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'created_at ASC',
      );
      return rows.map(AchievementModel.fromMap).toList();
    });
  }

  Future<Achievement?> getByUserAndType(String userId, String achievementType) {
    return guard('get_by_user_and_type', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        AchievementModel.table,
        where: 'user_id = ? AND achievement_type = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId, achievementType],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AchievementModel.fromMap(rows.first);
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
          AchievementModel.table,
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
          entity: AchievementModel.table,
          entityId: '$id',
          userId: existing['user_id'] as String,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<int> _insertInTxn(Transaction txn, Achievement achievement) async {
    // `achievement` is unique on (user_id, achievement_type) and the whole set
    // is recomputed after every session; keep the old ignore-duplicates
    // behaviour instead of throwing on the second insert.
    final String? type = achievement.achievementType;
    if (type != null && type.isNotEmpty) {
      final Map<String, Object?>? existing = await _findByUserAndType(
        txn,
        achievement.userId,
        type,
      );
      if (existing != null) {
        final int existingId = existing['id'] as int;
        if (existing['deleted_at'] != null) {
          await _updateInTxn(txn, achievement.copyWith(id: existingId));
        }
        return existingId;
      }
    }
    final int now = SyncableDao.nowMs();
    final Map<String, Object?> values = AchievementModel.toMap(achievement);
    values['uuid'] = SyncableDao.newUuid();
    values['created_at'] = values['created_at'] ?? now;
    values['updated_at'] = now;
    values['row_version'] = SyncableDao.firstRowVersion;
    values['achievement_def_id'] = await _resolveDefId(
      txn,
      values['achievement_type'],
    );
    final int id = await txn.insert(AchievementModel.table, values);
    await SyncableDao.recordCreate(
      txn,
      entity: AchievementModel.table,
      entityId: '$id',
      userId: achievement.userId,
    );
    return id;
  }

  Future<void> _updateInTxn(Transaction txn, Achievement achievement) async {
    final Map<String, Object?>? existing = await _findRow(txn, achievement.id);
    if (existing == null) return;
    final int now = SyncableDao.nowMs();
    final int baseVersion = _version(existing);
    final Map<String, Object?> values = AchievementModel.toMap(achievement);
    values['id'] = existing['id'];
    values['uuid'] = existing['uuid'] as String? ?? SyncableDao.newUuid();
    values['created_at'] = existing['created_at'] ?? values['created_at'];
    values['updated_at'] = now;
    values['row_version'] = baseVersion + 1;
    values['achievement_def_id'] =
        await _resolveDefId(txn, values['achievement_type']) ??
        existing['achievement_def_id'];
    // Clear a remotely applied tombstone when the achievement is re-unlocked.
    values['deleted_at'] = null;
    if (_sameSyncedValues(existing, values)) return;
    await txn.update(
      AchievementModel.table,
      values,
      where: 'id = ?',
      whereArgs: <Object?>[existing['id']],
    );
    await SyncableDao.recordUpdate(
      txn,
      entity: AchievementModel.table,
      entityId: '${existing['id']}',
      userId: existing['user_id'] as String,
      baseVersion: baseVersion,
    );
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      AchievementModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> _findByUserAndType(
    Transaction txn,
    String userId,
    String achievementType,
  ) async {
    final List<Map<String, Object?>> rows = await txn.query(
      AchievementModel.table,
      where: 'user_id = ? AND achievement_type = ?',
      whereArgs: <Object?>[userId, achievementType],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int?> _resolveDefId(Transaction txn, Object? achievementType) async {
    if (achievementType is! String || achievementType.isEmpty) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      _defTable,
      columns: const <String>['id'],
      where: 'achievement_type = ?',
      whereArgs: <Object?>[achievementType],
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
      'achievement_def_id',
      'is_unlocked',
      'unlocked_at',
    ];
    for (final String column in columns) {
      if (existing[column] != values[column]) return false;
    }
    return true;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
