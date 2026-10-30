import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/challenge.dart';
import '../../models/challenge_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `challenge` table.
///
/// Sync-aware (PROMPT 34 Batch 6): mutations record their outbox event in the
/// same transaction, maintain the sync columns and soft-delete. The cloud
/// `user_challenges` row only carries progress/completion, so `title`,
/// `description`, `difficulty` and `target` stay local. `challenge_def_id` is
/// resolved from the local master catalog by `type`; the push defers until the
/// catalog uuid is available.
class ChallengeLocalDataSource extends BaseLocalDataSource {
  ChallengeLocalDataSource({required super.database})
    : super(logName: 'ChallengeLocalDataSource');

  static const String _defTable = 'challenge_def';

  Future<int> insert(Challenge challenge) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = ChallengeModel.toMap(challenge);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        values['challenge_def_id'] = await _resolveDefId(txn, values['type']);
        final int id = await txn.insert(ChallengeModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: ChallengeModel.table,
          entityId: '$id',
          userId: challenge.userId,
        );
        return id;
      });
    });
  }

  Future<void> update(Challenge challenge) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> rows = await txn.query(
          ChallengeModel.table,
          where: 'id = ?',
          whereArgs: <Object?>[challenge.id],
          limit: 1,
        );
        if (rows.isEmpty) return;
        final Map<String, Object?> existing = rows.first;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = ChallengeModel.toMap(challenge);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String? ?? SyncableDao.newUuid();
        values['created_at'] = existing['created_at'] ?? values['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        values['challenge_def_id'] =
            await _resolveDefId(txn, values['type']) ??
            existing['challenge_def_id'];
        // Clear a remotely applied tombstone when the challenge is re-joined.
        values['deleted_at'] = null;
        if (_sameSyncedValues(existing, values)) return;
        await txn.update(
          ChallengeModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[existing['id']],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: ChallengeModel.table,
          entityId: '${existing['id']}',
          userId: existing['user_id'] as String,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<Challenge?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ChallengeModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ChallengeModel.fromMap(rows.first);
    });
  }

  Future<List<Challenge>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ChallengeModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(ChallengeModel.fromMap).toList();
    });
  }

  Future<Challenge?> getByUserAndType(String userId, String type) {
    return guard('get_by_user_and_type', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ChallengeModel.table,
        where: 'user_id = ? AND type = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId, type],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ChallengeModel.fromMap(rows.first);
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> rows = await txn.query(
          ChallengeModel.table,
          where: 'id = ?',
          whereArgs: <Object?>[id],
          limit: 1,
        );
        if (rows.isEmpty) return;
        final Map<String, Object?> existing = rows.first;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await txn.update(
          ChallengeModel.table,
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
          entity: ChallengeModel.table,
          entityId: '$id',
          userId: existing['user_id'] as String,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<int?> _resolveDefId(Transaction txn, Object? type) async {
    if (type is! String || type.isEmpty) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      _defTable,
      columns: const <String>['id'],
      where: 'challenge_type = ?',
      whereArgs: <Object?>[type],
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
      'challenge_def_id',
      'progress',
      'is_completed',
      'completed_at',
    ];
    for (final String column in columns) {
      if (existing[column] != values[column]) return false;
    }
    return true;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
