import 'dart:convert';

import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/sync_conflict_record.dart';
import '../../../domain/entities/security_enums.dart';
import 'app_database.dart';

/// SQLite data source for the durable conflict store (`sync_conflict`, PROMPT 19).
class SyncConflictLocalDataSource {
  SyncConflictLocalDataSource({required this.database});

  static const String table = 'sync_conflict';

  final AppDatabase database;

  Future<Database> get _db async => database.database;

  Future<void> record(SyncConflictRecord record) async {
    final Database db = await _db;
    await db.transaction((txn) async {
      // One pending record per (user, entity, record uuid); refresh the server
      // snapshot when the same unresolved row conflicts again.
      final List<Map<String, Object?>> existing = await txn.query(
        table,
        columns: const <String>['id'],
        where: "user_id = ? AND entity = ? AND record_uuid = ? "
            "AND status = ?",
        whereArgs: <Object?>[
          record.userId,
          record.entity,
          record.recordUuid,
          ConflictResolutionStatus.pending.name,
        ],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await txn.update(
          table,
          <String, Object?>{
            'server_data': record.serverData,
            'server_version': record.serverVersion,
            'server_updated_at':
                record.serverUpdatedAt?.millisecondsSinceEpoch,
            'local_data': record.localData,
            'local_version': record.localVersion,
            'local_updated_at': record.localUpdatedAt?.millisecondsSinceEpoch,
            'detected_at': record.detectedAt.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: <Object?>[existing.first['id']],
        );
        return;
      }
      await txn.insert(
        table,
        _toColumns(record),
      );
    });
  }

  Future<List<SyncConflictRecord>> getPending(String userId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'user_id = ? AND status = ?',
      whereArgs: <Object?>[
        userId,
        ConflictResolutionStatus.pending.name,
      ],
      orderBy: 'detected_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<SyncConflictRecord>> getHistory(
    String userId, {
    int limit = 50,
  }) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'detected_at DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> countPending(String userId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE user_id = ? AND status = ?',
      <Object?>[userId, ConflictResolutionStatus.pending.name],
    );
    return (rows.first['c'] as num).toInt();
  }

  Future<void> markResolved(int id, {required DateTime at}) async {
    final Database db = await _db;
    await db.update(
      table,
      <String, Object?>{
        'status': ConflictResolutionStatus.resolved.name,
        'resolved_at': at.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Map<String, Object?> _toColumns(SyncConflictRecord record) {
    return <String, Object?>{
      'user_id': record.userId,
      'entity': record.entity,
      'record_uuid': record.recordUuid,
      'local_data': record.localData,
      'server_data': record.serverData,
      'local_version': record.localVersion,
      'server_version': record.serverVersion,
      'local_updated_at': record.localUpdatedAt?.millisecondsSinceEpoch,
      'server_updated_at': record.serverUpdatedAt?.millisecondsSinceEpoch,
      'detected_at': record.detectedAt.millisecondsSinceEpoch,
      'status': record.status.name,
      'strategy': record.strategy.name,
      'resolved_at': record.resolvedAt?.millisecondsSinceEpoch,
    };
  }

  SyncConflictRecord _fromRow(Map<String, Object?> row) {
    return SyncConflictRecord(
      id: (row['id'] as num).toInt(),
      userId: row['user_id'] as String,
      entity: row['entity'] as String,
      recordUuid: row['record_uuid'] as String,
      localData: row['local_data'] as String?,
      serverData: row['server_data'] as String?,
      localVersion: (row['local_version'] as num?)?.toInt() ?? 0,
      serverVersion: (row['server_version'] as num?)?.toInt() ?? 0,
      localUpdatedAt: _epoch(row['local_updated_at']),
      serverUpdatedAt: _epoch(row['server_updated_at']),
      detectedAt:
          DateTime.fromMillisecondsSinceEpoch((row['detected_at'] as num).toInt()),
      status: ConflictResolutionStatus.fromName(row['status'] as String?),
      strategy: SyncConflictStrategy.fromName(row['strategy'] as String?),
      resolvedAt: _epoch(row['resolved_at']),
    );
  }

  DateTime? _epoch(Object? value) =>
      value == null ? null : DateTime.fromMillisecondsSinceEpoch((value as num).toInt());
}

/// Json helpers for conflict snapshots.
class SyncConflictJson {
  SyncConflictJson._();

  static String? encode(Map<String, Object?>? row) =>
      row == null || row.isEmpty ? null : jsonEncode(row);
}
