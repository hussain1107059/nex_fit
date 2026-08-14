import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/sync_state.dart';
import '../../models/sync_state_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `sync_state` table (per-user pull cursors).
class SyncStateLocalDataSource extends BaseLocalDataSource {
  SyncStateLocalDataSource({required super.database})
    : super(logName: 'SyncStateLocalDataSource');

  Future<SyncState?> getByUserId(String userId) {
    return guard('get_by_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        SyncStateModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return SyncStateModel.fromMap(rows.first);
    });
  }

  Future<void> upsert(SyncState state) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      await db.insert(
        SyncStateModel.table,
        SyncStateModel.toMap(state),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Advances [state] inside an existing [Transaction] so the cursor update
  /// commits atomically with the applied remote changes (Part 11).
  Future<void> upsertInTransaction(Transaction txn, SyncState state) {
    return guard('upsert_in_transaction', () async {
      await txn.insert(
        SyncStateModel.table,
        SyncStateModel.toMap(state),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}