import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/reminder.dart';
import '../../models/reminder_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `reminder` table.
///
/// Sync-aware (PROMPT 14 Batch 4): every mutation runs inside a transaction
/// together with its outbox event so the local row and its sync queue entry
/// commit (or roll back) atomically. Reads always filter out soft-deleted
/// rows; delete soft-deletes instead of destroying the row.
class ReminderLocalDataSource extends BaseLocalDataSource {
  ReminderLocalDataSource({required super.database})
    : super(logName: 'ReminderLocalDataSource');

  Future<int> insert(Reminder reminder) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = ReminderModel.toMap(reminder);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(ReminderModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: ReminderModel.table,
          entityId: '$id',
          userId: reminder.userId,
        );
        return id;
      });
    });
  }

  Future<void> update(Reminder reminder) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, reminder.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = ReminderModel.toMap(reminder);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String;
        values['created_at'] = values['created_at'] ?? existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          ReminderModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[reminder.id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: ReminderModel.table,
          entityId: '${reminder.id}',
          userId: reminder.userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<Reminder?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ReminderModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ReminderModel.fromMap(rows.first);
    });
  }

  Future<List<Reminder>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ReminderModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'time ASC',
      );
      return rows.map(ReminderModel.fromMap).toList();
    });
  }

  Future<List<Reminder>> getEnabled(String userId) {
    return guard('get_enabled', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ReminderModel.table,
        where: 'user_id = ? AND is_enabled = 1 AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'time ASC',
      );
      return rows.map(ReminderModel.fromMap).toList();
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
          ReminderModel.table,
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
          entity: ReminderModel.table,
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
      ReminderModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
