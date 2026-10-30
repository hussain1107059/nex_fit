import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/streak.dart';
import '../../models/streak_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `streak` table (one row per user + type).
///
/// Sync-aware (PROMPT 34 Batch 6): [upsert] is a transactional read-then-write
/// so the row keeps its `uuid`/`id` (a plain `ConflictAlgorithm.replace` would
/// delete and re-insert it, changing its cloud identity) and records exactly
/// one CREATE/UPDATE event. Streaks are recomputed often, so an unchanged
/// recomputation is a no-op and does not enqueue an event.
class StreakLocalDataSource extends BaseLocalDataSource {
  StreakLocalDataSource({required super.database})
    : super(logName: 'StreakLocalDataSource');

  Future<int> upsert(Streak streak) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final String streakType = streak.streakType.name;
        final List<Map<String, Object?>> rows = await txn.query(
          StreakModel.table,
          where: 'user_id = ? AND streak_type = ?',
          whereArgs: <Object?>[streak.userId, streakType],
          limit: 1,
        );
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = StreakModel.toMap(streak);
        if (rows.isNotEmpty) {
          final Map<String, Object?> existing = rows.first;
          final int baseVersion = _version(existing);
          values['id'] = existing['id'];
          values['uuid'] = existing['uuid'] as String? ?? SyncableDao.newUuid();
          values['created_at'] = existing['created_at'] ?? values['created_at'];
          values['updated_at'] = now;
          values['row_version'] = baseVersion + 1;
          // A remotely applied tombstone must be cleared when the user earns
          // the streak again.
          values['deleted_at'] = null;
          if (_sameSyncedValues(existing, values)) return existing['id'] as int;
          await txn.update(
            StreakModel.table,
            values,
            where: 'id = ?',
            whereArgs: <Object?>[existing['id']],
          );
          await SyncableDao.recordUpdate(
            txn,
            entity: StreakModel.table,
            entityId: '${existing['id']}',
            userId: streak.userId,
            baseVersion: baseVersion,
          );
          return existing['id'] as int;
        }
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(StreakModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: StreakModel.table,
          entityId: '$id',
          userId: streak.userId,
        );
        return id;
      });
    });
  }

  Future<Streak?> getByUserAndType(String userId, String streakType) {
    return guard('get_by_user_and_type', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StreakModel.table,
        where: 'user_id = ? AND streak_type = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId, streakType],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return StreakModel.fromMap(rows.first);
    });
  }

  Future<List<Streak>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StreakModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'streak_type ASC',
      );
      return rows.map(StreakModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> rows = await txn.query(
          StreakModel.table,
          where: 'id = ?',
          whereArgs: <Object?>[id],
          limit: 1,
        );
        if (rows.isEmpty) return;
        final Map<String, Object?> existing = rows.first;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await txn.update(
          StreakModel.table,
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
          entity: StreakModel.table,
          entityId: '$id',
          userId: existing['user_id'] as String,
          baseVersion: baseVersion,
        );
      });
    });
  }

  static bool _sameSyncedValues(
    Map<String, Object?> existing,
    Map<String, Object?> values,
  ) {
    // A tombstoned row is never "same": re-earning it must clear deleted_at and
    // push the resurrection.
    if (existing['deleted_at'] != null) return false;
    const List<String> columns = <String>[
      'streak_type',
      'current_streak',
      'longest_streak',
      'last_active_date',
      'best_date',
    ];
    for (final String column in columns) {
      if (existing[column] != values[column]) return false;
    }
    return true;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
