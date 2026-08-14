import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/step_log.dart';
import '../../models/step_log_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `step_log` table.
///
/// Sync-aware (PROMPT 13 Batch 3): every mutation runs inside a transaction
/// together with its outbox event. Step history can grow very large, so no
/// operation loads an entire table into memory: bulk writes go through a
/// single batched transaction and reads always target a single row or a
/// bounded date/user range.
class StepLogLocalDataSource extends BaseLocalDataSource {
  StepLogLocalDataSource({required super.database})
    : super(logName: 'StepLogLocalDataSource');

  Future<int> insert(StepLog log) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = StepLogModel.toMap(log);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(StepLogModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: StepLogModel.table,
          entityId: '$id',
          userId: log.userId,
        );
        return id;
      });
    });
  }

  /// Inserts many logs in a single transaction (never loads the table into
  /// memory); each row gets its own uuid and CREATE outbox event.
  Future<void> insertAll(List<StepLog> logs) {
    return guard('insert_all', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        for (final StepLog log in logs) {
          final Map<String, Object?> values = StepLogModel.toMap(log);
          values['uuid'] = SyncableDao.newUuid();
          values['created_at'] = values['created_at'] ?? now;
          values['updated_at'] = now;
          values['row_version'] = SyncableDao.firstRowVersion;
          final int id = await txn.insert(StepLogModel.table, values);
          await SyncableDao.recordCreate(
            txn,
            entity: StepLogModel.table,
            entityId: '$id',
            userId: log.userId,
          );
        }
      });
    });
  }

  Future<void> update(StepLog log) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, log.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = StepLogModel.toMap(log);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String;
        values['created_at'] = values['created_at'] ?? existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          StepLogModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[log.id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: StepLogModel.table,
          entityId: '${log.id}',
          userId: log.userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<StepLog?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StepLogModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return StepLogModel.fromMap(rows.first);
    });
  }

  Future<List<StepLog>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StepLogModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'step_date DESC',
      );
      return rows.map(StepLogModel.fromMap).toList();
    });
  }

  Future<StepLog?> getByDate(String userId, DateTime stepDate) {
    return guard('get_by_date', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StepLogModel.table,
        where: 'user_id = ? AND deleted_at IS NULL AND step_date = ?',
        whereArgs: <Object?>[userId, stepDate.millisecondsSinceEpoch],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return StepLogModel.fromMap(rows.first);
    });
  }

  Future<List<StepLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return guard('get_by_date_range', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        StepLogModel.table,
        where:
            'user_id = ? AND deleted_at IS NULL AND step_date >= ? AND step_date < ?',
        whereArgs: <Object?>[
          userId,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'step_date ASC',
      );
      return rows.map(StepLogModel.fromMap).toList();
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
          StepLogModel.table,
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
          entity: StepLogModel.table,
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
      StepLogModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
