import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/security_enums.dart';
import '../../datasources/local/app_database.dart';
import '../../models/local_user_model.dart';
import '../../models/sync_event_model.dart';
import 'sync_contracts.dart';
import 'sync_table_registry.dart';

/// Applies pulled remote changes to the local SQLite database (Part 10/11).
///
/// This is the REMOTE_APPLY path: it writes the local row directly, never
/// enqueuing a new outbox event, which prevents the push/pull echo loop
/// (Part 16). The caller passes a [Transaction] so the applied rows and the
/// cursor advance commit atomically.
///
/// Pull ordering for parent/child tables (PROMPT 12): the caller orders each
/// batch parents-before-children via [orderChangesForApply] so a child row
/// (e.g. `meal_item`) is only applied once its parent (`meal`) uuid resolves
/// locally. When a child's parent is not yet present, its local foreign key is
/// left null and the local NOT NULL FK constraint aborts the batch transaction;
/// the cursor therefore never advances past the unappliable row and it is
/// retried after the parent lands.
class RemoteChangeApplier {
  RemoteChangeApplier({required this.database});

  final AppDatabase database;

  /// Applies [change] to [txn]. Returns the number of local rows written
  /// (0 for a no-op like deleting an already-deleted row).
  ///
  /// Throws [UnsupportedTableException] when the cloud table has no local
  /// mapping so the sync engine can stop without advancing the cursor.
  Future<int> apply(Transaction txn, SyncChange change) async {
    final SyncTableMapping? mapping = SyncTableRegistry.byCloudTable(
      change.cloudTable,
    );
    if (mapping == null) {
      throw UnsupportedTableException(
        'No local mapping for cloud table "${change.cloudTable}"',
      );
    }

    final Map<String, Object?> localRow = _toLocalRow(
      mapping,
      change,
    );
    // The local `users` table is the FK parent for every `user_id`-keyed row
    // (user_profile, app_settings, user_level, ...). When a device's `users`
    // row is missing (a sign-in write that never landed, or a DB that lost the
    // row), applying any such row would abort the batch on the FK and the pull
    // safety-net would silently skip it — leaving the profile blank forever.
    // Insert a minimal parent row so the apply always succeeds.
    await _ensureUserRowIfMissing(txn, mapping, change, localRow);
    await _resolveForeignKeys(txn, mapping, localRow);

    if (change.isDelete) {
      return _applyDelete(txn, mapping, change.recordId);
    }
    return _upsert(txn, mapping, localRow);
  }

  /// Translates cloud uuid foreign keys back to local integer ids (PROMPT 11):
  /// cloud `workout_id` (uuid) -> local `workout_exercise.workout_id` (int).
  /// When the referenced row is not present locally yet the key is left unset
  /// and the local NOT NULL foreign key aborts the batch transaction, so the
  /// cursor never advances past an unappliable child row.
  Future<void> _resolveForeignKeys(
    Transaction txn,
    SyncTableMapping mapping,
    Map<String, Object?> localRow,
  ) async {
    for (final MapEntry<String, String> fk in mapping.cloudForeignKeys.entries) {
      final Object? cloudValue = localRow[fk.key];
      if (cloudValue is! String || cloudValue.isEmpty) continue;
      final List<Map<String, Object?>> rows = await txn.query(
        fk.value,
        columns: const <String>['id'],
        where: 'uuid = ?',
        whereArgs: <Object?>[cloudValue],
        limit: 1,
      );
      localRow[fk.key] = rows.isEmpty ? null : rows.first['id'];
    }
  }

  /// True when [tableName] has a registered local mapping.
  bool isSupported(String cloudTable) =>
      SyncTableRegistry.byCloudTable(cloudTable) != null;

  /// Idempotently guarantees the `users` parent row referenced by [localRow]'s
  /// `user_id` exists. A minimal placeholder is inserted only when the row is
  /// absent; a real sign-in write is never overwritten. Returns early for
  /// non-user-keyed rows.
  Future<void> _ensureUserRowIfMissing(
    Transaction txn,
    SyncTableMapping mapping,
    SyncChange change,
    Map<String, Object?> localRow,
  ) async {
    final Object? userId = localRow['user_id'];
    if (userId is! String || userId.isEmpty) return;
    final List<Map<String, Object?>> existing = await txn.query(
      LocalUserModel.table,
      columns: const <String>['id'],
      where: 'id = ?',
      whereArgs: <Object?>[userId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final Object? displayName = change.payload['display_name'];
    await txn.insert(
      LocalUserModel.table,
      <String, Object?>{
        'id': userId,
        'name': displayName is String ? displayName : '',
        'email': '',
        'provider': AuthProvider.none.name,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Map<String, Object?> _toLocalRow(
    SyncTableMapping mapping,
    SyncChange change,
  ) {
    final Map<String, String> cloudToLocal = <String, String>{
      for (final MapEntry<String, String> entry
          in mapping.localToCloud.entries)
        entry.value: entry.key,
    };

    final Map<String, Object?> localRow = <String, Object?>{
      'uuid': change.recordId,
      'user_id': change.isDelete ? '' : _userIdFor(mapping, change),
    };
    // Always stamp sync metadata from the remote snapshot.
    localRow.addAll(
      _syncColumnsFromPayload(mapping, change.payload),
    );

    for (final MapEntry<String, Object?> entry in change.payload.entries) {
      final String? localColumn = cloudToLocal[entry.key];
      if (localColumn == null) continue;
      final Object? value = _convertCloudValue(
        mapping,
        entry.key,
        entry.value,
      );
      localRow[localColumn] = value;
    }
    // Foreign keys share their name on both sides and are not part of
    // [localToCloud]; carry the cloud uuid over so `_resolveForeignKeys` can
    // translate it back to the local integer id.
    for (final MapEntry<String, String> fk in mapping.cloudForeignKeys.entries) {
      final String cloudName = mapping.cloudForeignKeyNames[fk.key] ?? fk.key;
      final Object? value = change.payload[cloudName];
      if (value != null) localRow[fk.key] = value;
    }
    return localRow;
  }

  String _userIdFor(SyncTableMapping mapping, SyncChange change) {
    // Singletons keyed by user_id reuse the user id as their primary identity.
    final Object? fromPayload = change.payload['user_id'];
    if (fromPayload is String && fromPayload.isNotEmpty) return fromPayload;
    return change.payload['id'] as String? ?? '';
  }

  Map<String, Object?> _syncColumnsFromPayload(
    SyncTableMapping mapping,
    Map<String, Object?> payload,
  ) {
    final Map<String, Object?> columns = <String, Object?>{};
    final Object? rowVersion = payload['row_version'];
    if (rowVersion is num) {
      columns['row_version'] = rowVersion.toInt();
    }
    final Object? updatedAt = _convertCloudValue(
      mapping,
      'updated_at',
      payload['updated_at'],
    );
    if (updatedAt != null) columns['updated_at'] = updatedAt;
    final Object? deletedAt = _convertCloudValue(
      mapping,
      'deleted_at',
      payload['deleted_at'],
    );
    if (deletedAt != null) columns['deleted_at'] = deletedAt;
    final Object? createdAt = _convertCloudValue(
      mapping,
      'created_at',
      payload['created_at'],
    );
    if (createdAt != null) columns['created_at'] = createdAt;
    return columns;
  }

  Object? _convertCloudValue(
    SyncTableMapping mapping,
    String cloudColumn,
    Object? value,
  ) {
    if (value == null) return null;
    // Sync metadata columns are always `timestamptz` on the cloud, regardless
    // of a table's [timestampColumns] (which may omit deleted_at).
    if (cloudColumn == 'created_at' ||
        cloudColumn == 'updated_at' ||
        cloudColumn == 'deleted_at') {
      if (value is String) {
        final DateTime? parsed = DateTime.tryParse(value);
        return parsed?.millisecondsSinceEpoch;
      }
      if (value is num) return value.toInt();
      return null;
    }
    if (mapping.timestampColumns.contains(cloudColumn)) {
      if (value is String) {
        final DateTime? parsed = DateTime.tryParse(value);
        return parsed?.millisecondsSinceEpoch;
      }
      if (value is num) return value.toInt();
      return null;
    }
    if (mapping.dateColumns.contains(cloudColumn)) {
      // Cloud `date` columns arrive as 'YYYY-MM-DD'; round-trips the transport's
      // local-calendar rendering back to a local epoch-ms midnight.
      if (value is String) {
        final DateTime? parsed = DateTime.tryParse(value);
        return parsed?.millisecondsSinceEpoch;
      }
      if (value is num) return value.toInt();
      return null;
    }
    if (mapping.booleanColumns.contains(cloudColumn)) {
      return value == true ? 1 : 0;
    }
    return value;
  }

  Future<int> _upsert(
    Transaction txn,
    SyncTableMapping mapping,
    Map<String, Object?> localRow,
  ) async {
    final String where = mapping.localKeyColumn == 'user_id'
        ? 'user_id = ?'
        : 'uuid = ?';
    final String whereArg = mapping.localKeyColumn == 'user_id'
        ? (localRow['user_id'] as String)
        : (localRow['uuid'] as String);

    final List<Map<String, Object?>> existing = await txn.query(
      mapping.localTable,
      where: where,
      whereArgs: <Object?>[whereArg],
      limit: 1,
    );
    if (existing.isEmpty) {
      await txn.insert(mapping.localTable, localRow);
      return 1;
    }
    // Never regress a row that holds a genuinely newer local write. When the
    // existing local row has a higher row_version than the change being applied,
    // the change is a replayed/older entry (e.g. an INSERT re-pulled after a
    // local completion) and must be skipped so it cannot revert local data.
    // Equal versions still overwrite: re-applying the same snapshot is
    // idempotent and harmless.
    final Object? incomingVersion = localRow['row_version'];
    final Object? existingVersion = existing.first['row_version'];
    if (incomingVersion is int &&
        existingVersion is int &&
        existingVersion > incomingVersion) {
      // Only skip when the row still has an outbox event that represents a
      // real local write (in flight, pending retry, or permanently failed but
      // not yet on the server). A row whose version merely drifted above the
      // remote WITHOUT any outbox event is stale, not newer: the authoritative
      // server snapshot must be allowed to repair it, or a fresh pull could
      // never converge.
      final bool hasPendingWrite = await _hasPendingOutboxEvent(
        txn,
        mapping,
        existing.first,
        whereArg,
        incomingVersion,
      );
      if (hasPendingWrite) return 0;
    }
    await txn.update(
      mapping.localTable,
      localRow,
      where: where,
      whereArgs: <Object?>[whereArg],
    );
    return 1;
  }

  /// True when [table]'s row still has an outbox event that must protect it
  /// from being regressed by a stale server snapshot. The DAOs key non-singleton
  /// events by the local rowid and singleton events by the user id, so both
  /// identifiers are probed.
  ///
  /// In-flight writes (`pending`, `processing`, `failedRetryable`) always
  /// protect the row: they will be pushed and the server will catch up. A
  /// `failedPermanent` write will never reach the server, so it only protects
  /// the row against snapshots that are NOT newer than that write's basis —
  /// when the incoming snapshot's version exceeds the event's `base_version`
  /// the server is authoritative and the row must be allowed to advance, or a
  /// permanently-failed row could never converge.
  Future<bool> _hasPendingOutboxEvent(
    Transaction txn,
    SyncTableMapping mapping,
    Map<String, Object?> existing,
    String recordId,
    int incomingVersion,
  ) async {
    final Object? rowId = existing['id'];
    final List<Map<String, Object?>> rows = await txn.query(
      SyncEventModel.table,
      columns: const <String>['status', 'base_version'],
      where: 'entity = ? AND entity_id IN (?, ?) AND status IN (?, ?, ?, ?)',
      whereArgs: <Object?>[
        mapping.localTable,
        '$rowId',
        recordId,
        SyncStatus.pending.name,
        SyncStatus.failedRetryable.name,
        SyncStatus.processing.name,
        SyncStatus.failedPermanent.name,
      ],
    );
    if (rows.isEmpty) return false;
    for (final Map<String, Object?> row in rows) {
      final String? status = row['status'] as String?;
      if (status != SyncStatus.failedPermanent.name) return true;
      final Object? baseVersion = row['base_version'];
      if (baseVersion is int && baseVersion >= incomingVersion) return true;
    }
    return false;
  }

  Future<int> _applyDelete(
    Transaction txn,
    SyncTableMapping mapping,
    String recordId,
  ) async {
    final String where = mapping.localKeyColumn == 'user_id'
        ? 'user_id = ?'
        : 'uuid = ?';
    final String whereArg = recordId;
    final List<Map<String, Object?>> existing = await txn.query(
      mapping.localTable,
      where: where,
      whereArgs: <Object?>[whereArg],
      limit: 1,
    );
    if (existing.isEmpty) return 0;
    await txn.update(
      mapping.localTable,
      <String, Object?>{
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: where,
      whereArgs: <Object?>[whereArg],
    );
    return 1;
  }
}

/// Raised when a pulled change targets a cloud table with no local mapping.
class UnsupportedTableException implements Exception {
  const UnsupportedTableException(this.message);

  final String message;

  @override
  String toString() => 'UnsupportedTableException($message)';
}

/// Orders a pull [changes] batch so parent rows are applied before the child
/// rows that reference them (PROMPT 12). Dependency edges come from each
/// mapping's `cloudForeignKeys`: a child cloud table must be applied after any
/// cloud table it references. Within a rank the original order is preserved.
/// Cycles (none exist today) fall back to the input order rather than looping.
List<SyncChange> orderChangesForApply(List<SyncChange> changes) {
  if (changes.length < 2) return changes;

  final Map<String, Set<String>> dependencies = <String, Set<String>>{};
  for (final SyncChange change in changes) {
    final SyncTableMapping? mapping = SyncTableRegistry.byCloudTable(
      change.cloudTable,
    );
    final Set<String> deps = <String>{};
    if (mapping != null) {
      for (final String referencedLocalTable in mapping.cloudForeignKeys.values) {
        final SyncTableMapping? parent = SyncTableRegistry.byLocalTable(
          referencedLocalTable,
        );
        if (parent != null && parent.cloudTable != change.cloudTable) {
          deps.add(parent.cloudTable);
        }
      }
    }
    dependencies[change.cloudTable] = deps;
  }

  final List<SyncChange> ordered = <SyncChange>[];
  final List<SyncChange> remaining = changes.toList();
  while (remaining.isNotEmpty) {
    int picked = -1;
    for (int i = 0; i < remaining.length; i++) {
      final SyncChange candidate = remaining[i];
      final Set<String> deps = dependencies[candidate.cloudTable] ??
          const <String>{};
      final bool ready = deps.every(
        (String dep) => !remaining.any((SyncChange other) =>
            other.cloudTable == dep && !identical(other, candidate)),
      );
      if (ready) {
        picked = i;
        break;
      }
    }
    if (picked == -1) {
      // Cycle or unresolvable dependency: emit the rest unchanged.
      ordered.addAll(remaining);
      break;
    }
    ordered.add(remaining[picked]);
    remaining.removeAt(picked);
  }
  return ordered;
}