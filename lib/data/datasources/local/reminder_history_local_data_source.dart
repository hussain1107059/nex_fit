import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/reminder_history.dart';
import '../../models/reminder_history_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `reminder_history` table.
///
/// Sync-aware (PROMPT 14 Batch 4): occurrence events are source-of-truth user
/// data. Every mutation runs inside a transaction with its outbox event;
/// deleting a reminder soft-deletes its history rows one-by-one, each carrying
/// its own DELETE event (mirroring the meal/meal_item child tombstone pattern),
/// so remote devices learn about every removal.
class ReminderHistoryLocalDataSource extends BaseLocalDataSource {
  ReminderHistoryLocalDataSource({required super.database})
    : super(logName: 'ReminderHistoryLocalDataSource');

  Future<int> insert(ReminderHistory history) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = ReminderHistoryModel.toMap(history);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(ReminderHistoryModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: ReminderHistoryModel.table,
          entityId: '$id',
          userId: history.userId,
        );
        return id;
      });
    });
  }

  Future<void> insertAll(List<ReminderHistory> history) {
    return guard('insert_all', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        for (final ReminderHistory entry in history) {
          final Map<String, Object?> values = ReminderHistoryModel.toMap(entry);
          values['uuid'] = SyncableDao.newUuid();
          values['created_at'] = values['created_at'] ?? now;
          values['updated_at'] = now;
          values['row_version'] = SyncableDao.firstRowVersion;
          final int id = await txn.insert(ReminderHistoryModel.table, values);
          await SyncableDao.recordCreate(
            txn,
            entity: ReminderHistoryModel.table,
            entityId: '$id',
            userId: entry.userId,
          );
        }
      });
    });
  }

  Future<void> update(ReminderHistory history) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, history.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = ReminderHistoryModel.toMap(history);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String;
        values['created_at'] = values['created_at'] ?? existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          ReminderHistoryModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[history.id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: ReminderHistoryModel.table,
          entityId: '${history.id}',
          userId: history.userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<List<ReminderHistory>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ReminderHistoryModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'scheduled_for DESC',
      );
      return rows.map(ReminderHistoryModel.fromMap).toList();
    });
  }

  Future<List<ReminderHistory>> getByReminderId(int reminderId) {
    return guard('get_by_reminder_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ReminderHistoryModel.table,
        where: 'reminder_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[reminderId],
        orderBy: 'scheduled_for DESC',
      );
      return rows.map(ReminderHistoryModel.fromMap).toList();
    });
  }

  Future<List<ReminderHistory>> getByStatus(
    String userId,
    ReminderHistoryStatus status,
  ) {
    return guard('get_by_status', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ReminderHistoryModel.table,
        where: 'user_id = ? AND status = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId, status.name],
        orderBy: 'scheduled_for DESC',
      );
      return rows.map(ReminderHistoryModel.fromMap).toList();
    });
  }

  Future<List<DateTime>> getScheduledFor(int reminderId) {
    return guard('get_scheduled_for', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ReminderHistoryModel.table,
        columns: <String>['scheduled_for'],
        where: 'reminder_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[reminderId],
      );
      return rows
          .map((Map<String, Object?> row) => row['scheduled_for'] as int)
          .map(DateTime.fromMillisecondsSinceEpoch)
          .toList();
    });
  }

  /// Soft-deletes every history row for [reminderId], emitting one DELETE
  /// outbox event per row so the removal propagates to other devices.
  Future<void> deleteByReminderId(int reminderId) {
    return guard('delete_by_reminder_id', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final List<Map<String, Object?>> rows = await txn.query(
          ReminderHistoryModel.table,
          where: 'reminder_id = ? AND deleted_at IS NULL',
          whereArgs: <Object?>[reminderId],
        );
        for (final Map<String, Object?> row in rows) {
          final int id = row['id'] as int;
          final int baseVersion = _version(row);
          await txn.update(
            ReminderHistoryModel.table,
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
            entity: ReminderHistoryModel.table,
            entityId: '$id',
            userId: row['user_id'] as String,
            baseVersion: baseVersion,
          );
        }
      });
    });
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      ReminderHistoryModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
