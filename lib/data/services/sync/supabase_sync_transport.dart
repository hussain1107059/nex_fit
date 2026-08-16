import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../domain/entities/security_enums.dart';
import '../../../domain/entities/sync_event.dart';
import '../../../supabase_options.dart';
import '../../datasources/local/app_database.dart';
import '../supabase/supabase_service.dart';
import 'sync_contracts.dart';
import 'sync_log.dart';
import 'sync_table_registry.dart';

/// Real Supabase-backed [SyncTransport].
///
/// Idempotency (Part 8) needs no schema change: the cloud row's `id` is the
/// local row `uuid`, and every write is an upsert keyed on that id, so a
/// retried event can never create a duplicate row. Optimistic conflict
/// detection (Part 9) is done server-side with a conditional update on
/// `row_version`.
class SupabaseSyncTransport implements SyncTransport {
  SupabaseSyncTransport({
    required this.service,
    required this.database,
    Logger? logger,
  }) : _logger = logger ?? Logger('SupabaseSyncTransport');

  final SupabaseService service;
  final AppDatabase database;
  final Logger _logger;

  @override
  String get name => 'supabase';

  @override
  bool get isReady {
    final supabase.SupabaseClient? client = service.client;
    return service.isReady && client != null && SupabaseOptions.isConfigured;
  }

  supabase.SupabaseClient get _client {
    final supabase.SupabaseClient? client = service.client;
    if (client == null) {
      throw const SyncTransportException('supabase_not_initialized');
    }
    return client;
  }

  void _requireUserId(String userId) {
    final String? sessionUserId = _client.auth.currentSession?.user.id;
    if (sessionUserId == null || sessionUserId.isEmpty) {
      // Auth expired: never treat as permanent (the prompt forbids permanently
      // dropping events on auth expiry).
      throw const SyncTransportException('auth_session_expired');
    }
    // Defense in depth: the event must belong to the authenticated user. The
    // authoritative check is server-side RLS, but this client guard closes the
    // gap before a cross-user write is even attempted.
    if (sessionUserId != userId) {
      throw SyncTransportException(
        'security_policy_violation',
        retryable: false,
      );
    }
  }

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    _requireUserId(event.userId);

    final SyncTableMapping? mapping = SyncTableRegistry.byLocalTable(
      event.entity,
    );
    if (mapping == null) {
      return const SyncPushResult(
        applied: false,
        lastError: 'unsupported_entity',
      );
    }

    final Map<String, Object?>? localRow = await _readLocalRow(
      mapping,
      event,
    );

    try {
      switch (event.operation) {
        case SyncOperation.create:
        case SyncOperation.update:
          if (localRow == null) {
            return const SyncPushResult(
              applied: false,
              lastError: 'local_row_missing',
            );
          }
          return _write(mapping, event, localRow);
        case SyncOperation.delete:
          return _remove(mapping, event, localRow);
      }
    } on supabase.PostgrestException catch (error) {
      _logger.warning(
        '[PUSH_FAILURE] event=${SyncLog.maskEventUuid(event.eventUuid)} '
        'table=${mapping.cloudTable} code=${error.code} message=${error.message}',
      );
      throw SyncTransportException(
        'postgrest_${error.code}_${error.message}',
        retryable: true,
      );
    }
  }

  Future<Map<String, Object?>?> _readLocalRow(
    SyncTableMapping mapping,
    SyncEvent event,
  ) async {
    final Database db = await database.database;
    final List<Map<String, Object?>> rows = await db.query(
      mapping.localTable,
      where: '${mapping.localKeyColumn} = ?',
      whereArgs: <Object?>[
        mapping.localKeyColumn == 'user_id'
            ? event.userId
            : event.entityId,
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>> _buildCloudRow(
    SyncTableMapping mapping,
    Map<String, Object?> localRow,
  ) async {
    final Map<String, Object?> cloud = <String, Object?>{
      'id': localRow['uuid'] as String,
      'user_id': (localRow['user_id'] as String?) ?? '',
      'row_version': (localRow['row_version'] as num?)?.toInt() ?? 0,
    };
    if (mapping.cloudHasDeletedAt) {
      // Send the tombstone (null or ISO) so a locally resurrected row clears
      // the cloud deleted_at on the next create/update push (PROMPT 12).
      final Object? deletedAt = localRow['deleted_at'];
      cloud['deleted_at'] = deletedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((deletedAt as num).toInt())
              .toUtc()
              .toIso8601String();
    }
    for (final MapEntry<String, String> entry in mapping.localToCloud.entries) {
      final Object? value = localRow[entry.key];
      cloud[entry.value] = _convertLocalValue(mapping, entry.value, value);
    }
    await _resolveCloudForeignKeys(mapping, localRow, cloud);
    return cloud;
  }

  /// Translates local integer foreign keys to the referenced row's cloud uuid
  /// (PROMPT 11): local `workout_exercise.workout_id` -> `workouts.id` (uuid).
  Future<void> _resolveCloudForeignKeys(
    SyncTableMapping mapping,
    Map<String, Object?> localRow,
    Map<String, Object?> cloud,
  ) async {
    if (mapping.cloudForeignKeys.isEmpty) return;
    final Database db = await database.database;
    for (final MapEntry<String, String> fk in mapping.cloudForeignKeys.entries) {
      final Object? localId = localRow[fk.key];
      if (localId == null) continue;
      final List<Map<String, Object?>> rows = await db.query(
        fk.value,
        columns: const <String>['uuid'],
        where: 'id = ?',
        whereArgs: <Object?>[localId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final String cloudName =
            mapping.cloudForeignKeyNames[fk.key] ?? fk.key;
        cloud[cloudName] = rows.first['uuid'];
      }
    }
  }

  Object? _convertLocalValue(
    SyncTableMapping mapping,
    String cloudColumn,
    Object? value,
  ) {
    if (value == null) return null;
    if (mapping.timestampColumns.contains(cloudColumn)) {
      final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
        (value as num).toInt(),
      );
      return dt.toUtc().toIso8601String();
    }
    if (mapping.dateColumns.contains(cloudColumn)) {
      final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
        (value as num).toInt(),
      );
      return '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    }
    if (mapping.booleanColumns.contains(cloudColumn)) {
      return value == 1;
    }
    return value;
  }

  Future<SyncPushResult> _write(
    SyncTableMapping mapping,
    SyncEvent event,
    Map<String, Object?> localRow,
  ) async {
    final Map<String, Object?> cloudRow = await _buildCloudRow(mapping, localRow);
    // Remove user_id override for singletons: profiles.user_id does not exist.
    if (mapping.cloudTable == 'profiles') {
      cloudRow.remove('user_id');
    }

    if (event.operation == SyncOperation.create || event.baseVersion == 0) {
      // Idempotent upsert keyed on the record uuid (Part 8).
      final List<Map<String, dynamic>> rows = await _client
          .from(mapping.cloudTable)
          .upsert(cloudRow, onConflict: 'id')
          .select('row_version');
      return SyncPushResult(
        applied: true,
        serverRowVersion: rows.isEmpty
            ? null
            : (rows.first['row_version'] as num?)?.toInt(),
      );
    }

    // Optimistic concurrency check (Part 9): update only when the remote
    // row_version still equals the event's base_version.
    final List<Map<String, dynamic>> rows = await _client
        .from(mapping.cloudTable)
        .update(cloudRow)
        .eq('id', cloudRow['id'] as Object)
        .eq('row_version', event.baseVersion as Object)
        .select('row_version');
    if (rows.isEmpty) {
      // Stale write (PROMPT 19): the remote row moved past our base_version.
      // Fetch the current server row so the engine can capture both sides in
      // the durable conflict record instead of silently overwriting.
      final List<Map<String, dynamic>> current = await _client
          .from(mapping.cloudTable)
          .select()
          .eq('id', cloudRow['id'] as Object)
          .limit(1);
      if (current.isEmpty) {
        // The remote row no longer exists (deleted by another device); the
        // server still wins - the pull applies the tombstone locally.
        return const SyncPushResult(applied: false, conflict: true);
      }
      final Map<String, dynamic> server = current.first;
      return SyncPushResult(
        applied: false,
        conflict: true,
        serverRowVersion: (server['row_version'] as num?)?.toInt(),
        serverData: Map<String, Object?>.from(server),
        serverUpdatedAt: _parseServerUpdatedAt(server['updated_at']),
      );
    }
    return SyncPushResult(
      applied: true,
      serverRowVersion: (rows.first['row_version'] as num?)?.toInt(),
    );
  }

  Future<SyncPushResult> _remove(
    SyncTableMapping mapping,
    SyncEvent event,
    Map<String, Object?>? localRow,
  ) async {
    if (mapping.cloudTable == 'profiles') {
      // The profile row is the auth identity; it cannot be deleted via sync.
      return const SyncPushResult(applied: true);
    }
    final String? id = localRow?['uuid'] as String?;
    if (id == null) {
      // Row already gone locally: attempt by known uuid from event is not
      // available, so acknowledge (idempotent delete).
      return const SyncPushResult(applied: true);
    }
    // Soft delete so the tombstone survives and triggers a DELETE change.
    // The update is conditional on row_version == base_version so a delete of
    // a row another device changed since our last read surfaces as a conflict
    // (delete-vs-update, PROMPT 19) instead of silently deleting the newer
    // server row.
    final List<Map<String, dynamic>> rows = await _client
        .from(mapping.cloudTable)
        .update(<String, Object?>{
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('row_version', event.baseVersion as Object)
        .select('row_version');
    if (rows.isEmpty) {
      final List<Map<String, dynamic>> current = await _client
          .from(mapping.cloudTable)
          .select()
          .eq('id', id)
          .limit(1);
      if (current.isEmpty) {
        // Already deleted on the server: idempotent success.
        return const SyncPushResult(applied: true);
      }
      final Map<String, dynamic> server = current.first;
      return SyncPushResult(
        applied: false,
        conflict: true,
        serverRowVersion: (server['row_version'] as num?)?.toInt(),
        serverData: Map<String, Object?>.from(server),
        serverUpdatedAt: _parseServerUpdatedAt(server['updated_at']),
      );
    }
    return SyncPushResult(
      applied: true,
      serverRowVersion: (rows.first['row_version'] as num?)?.toInt(),
    );
  }

  DateTime? _parseServerUpdatedAt(Object? value) {
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    _requireUserId(userId);

    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('sync_changes')
          .select()
          .eq('user_id', userId)
          .gt('id', cursor)
          .order('id')
          .limit(limit);

      final List<SyncChange> changes = <SyncChange>[];
      int nextCursor = cursor;
      for (final Map<String, dynamic> row in rows) {
        final int id = (row['id'] as num).toInt();
        if (id > nextCursor) nextCursor = id;
        final String? rawPayload = row['payload'] as String?;
        final Map<String, Object?> payload = rawPayload == null
            ? <String, Object?>{}
            : _decodePayload(rawPayload);
        changes.add(
          SyncChange(
            cursorId: id,
            cloudTable: row['table_name'] as String,
            recordId: row['record_id'] as String,
            operation: _operationFrom(row['operation'] as String?),
            payload: payload,
          ),
        );
      }
      return SyncPullBatch(
        changes: changes,
        nextCursor: nextCursor,
        hasMore: changes.length == limit,
      );
    } on supabase.PostgrestException catch (error) {
      SyncLog.warning(
        _logger,
        SyncLog.pullFailure,
        'user=${SyncLog.maskUserId(userId)} code=${error.code} '
        'message=${error.message}',
      );
      throw SyncTransportException(
        'postgrest_${error.code}_${error.message}',
        retryable: true,
      );
    }
  }

  Map<String, Object?> _decodePayload(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (String key, dynamic value) => MapEntry<String, Object?>(key, value),
        );
      }
    } catch (_) {
      // Fall through to empty payload.
    }
    return <String, Object?>{};
  }

  SyncOperation _operationFrom(String? value) {
    switch (value) {
      case 'INSERT':
        return SyncOperation.create;
      case 'DELETE':
        return SyncOperation.delete;
      default:
        return SyncOperation.update;
    }
  }
}