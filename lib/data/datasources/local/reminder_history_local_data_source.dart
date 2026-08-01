import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/reminder_history.dart';
import '../../models/reminder_history_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `reminder_history` table.
class ReminderHistoryLocalDataSource extends BaseLocalDataSource {
  ReminderHistoryLocalDataSource({required super.database})
    : super(logName: 'ReminderHistoryLocalDataSource');

  Future<int> insert(ReminderHistory history) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        ReminderHistoryModel.table,
        ReminderHistoryModel.toMap(history),
      );
    });
  }

  Future<void> insertAll(List<ReminderHistory> history) {
    return guard('insert_all', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = history
          .map(ReminderHistoryModel.toMap)
          .toList(growable: false);
      await db.transaction((Transaction txn) async {
        final Batch batch = txn.batch();
        for (final Map<String, Object?> row in rows) {
          batch.insert(ReminderHistoryModel.table, row);
        }
        await batch.commit(noResult: true);
      });
    });
  }

  Future<void> update(ReminderHistory history) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        ReminderHistoryModel.table,
        ReminderHistoryModel.toMap(history),
        where: 'id = ?',
        whereArgs: <Object?>[history.id],
      );
    });
  }

  Future<List<ReminderHistory>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ReminderHistoryModel.table,
        where: 'user_id = ?',
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
        where: 'reminder_id = ?',
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
        where: 'user_id = ? AND status = ?',
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
        where: 'reminder_id = ?',
        whereArgs: <Object?>[reminderId],
      );
      return rows
          .map((Map<String, Object?> row) => row['scheduled_for'] as int)
          .map(DateTime.fromMillisecondsSinceEpoch)
          .toList();
    });
  }

  Future<void> deleteByReminderId(int reminderId) {
    return guard('delete_by_reminder_id', () async {
      final Database db = await dbConnection;
      await db.delete(
        ReminderHistoryModel.table,
        where: 'reminder_id = ?',
        whereArgs: <Object?>[reminderId],
      );
    });
  }
}
