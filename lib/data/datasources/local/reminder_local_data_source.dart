import 'dart:async';

import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/reminder.dart';
import '../../../domain/entities/security_enums.dart';
import '../../models/reminder_model.dart';
import '../../services/sync/sync_event_recorder.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `reminder` table.
class ReminderLocalDataSource extends BaseLocalDataSource {
  ReminderLocalDataSource({required super.database})
    : super(logName: 'ReminderLocalDataSource');

  Future<int> insert(Reminder reminder) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      final int id = await db.insert(
        ReminderModel.table,
        ReminderModel.toMap(reminder),
      );
      unawaited(
        SyncEventRecorder.record(
          entity: ReminderModel.table,
          entityId: '$id',
          operation: SyncOperation.create,
          userId: reminder.userId,
        ),
      );
      return id;
    });
  }

  Future<void> update(Reminder reminder) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        ReminderModel.table,
        ReminderModel.toMap(reminder),
        where: 'id = ?',
        whereArgs: <Object?>[reminder.id],
      );
      unawaited(
        SyncEventRecorder.record(
          entity: ReminderModel.table,
          entityId: '${reminder.id}',
          operation: SyncOperation.update,
          userId: reminder.userId,
        ),
      );
    });
  }

  Future<Reminder?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ReminderModel.table,
        where: 'id = ?',
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
        where: 'user_id = ?',
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
        where: 'user_id = ? AND is_enabled = 1',
        whereArgs: <Object?>[userId],
        orderBy: 'time ASC',
      );
      return rows.map(ReminderModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        ReminderModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      unawaited(
        SyncEventRecorder.record(
          entity: ReminderModel.table,
          entityId: '$id',
          operation: SyncOperation.delete,
        ),
      );
    });
  }
}
