import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../../core/constants/app_constants.dart';
import '../../datasources/local/app_database.dart';
import '../../datasources/local/master_catalog_state_local_data_source.dart';
import 'master_data_contracts.dart';
import 'sync_log.dart';

/// Server-authoritative master-catalog sync (PROMPT 16).
///
/// The client is SELECT-only: master catalogs are downloaded, applied
/// idempotently to the local tables and never pushed back. The service:
///
/// * compares the stored `data_version` against `public.master_data_versions`
///   and skips downloads when nothing changed;
/// * pulls incrementally by `updated_at >= since` (a high-water mark, so a
///   bulk publish that reuses old row timestamps can never lose rows);
/// * applies each batch inside one transaction, adopting existing seeded rows
///   in place by natural key (slug / name / goal_type) so local integer ids —
///   and therefore every FK from user data — stay valid;
/// * keeps the last good local catalog AND version on any failure, recording
///   only `last_error` (never dropping or tombstoning local rows);
/// * never performs reconcile-deletes: remote soft-deletes (tombstones) are
///   the only deletions applied.
class MasterDataSyncService {
  MasterDataSyncService({
    required this.database,
    required this.transport,
    required this.stateDataSource,
    Logger? logger,
  }) : _logger = logger ?? Logger('MasterDataSyncService');

  final AppDatabase database;
  final MasterDataTransport transport;
  final MasterCatalogStateLocalDataSource stateDataSource;
  final Logger _logger;

  /// Runs the full catalog sync in dependency order. Offline (no transport)
  /// returns immediately without touching the local data.
  Future<MasterDataSyncResult> syncAll({DateTime? now}) async {
    if (!transport.isReady) {
      return const MasterDataSyncResult(ran: false);
    }
    final DateTime at = now ?? DateTime.now();
    final List<MasterCatalogSyncResult> results = <MasterCatalogSyncResult>[];
    for (final MasterCatalogSpec spec in MasterCatalogRegistry.catalogs) {
      final MasterCatalogSyncResult result = await _syncCatalog(spec, at: at);
      results.add(result);
      SyncLog.info(
        _logger,
        'MASTER_SYNC',
        'catalog=${spec.catalog} '
        'skipped=${result.skipped} succeeded=${result.succeeded} '
        'applied=${result.applied} version=${result.dataVersion}',
      );
    }
    return MasterDataSyncResult(catalogs: results);
  }

  /// Syncs a single catalog (used by the UI for one-off refreshes).
  Future<MasterCatalogSyncResult> syncCatalog(
    String catalog, {
    DateTime? now,
  }) async {
    final MasterCatalogSpec? spec = MasterCatalogRegistry.byCatalog(catalog);
    if (spec == null) {
      return MasterCatalogSyncResult(
        catalog: catalog,
        error: 'unsupported_catalog_$catalog',
      );
    }
    if (!transport.isReady) {
      return MasterCatalogSyncResult(
        catalog: catalog,
        error: 'transport_not_ready',
      );
    }
    return _syncCatalog(spec, at: now ?? DateTime.now());
  }

  Future<MasterCatalogSyncResult> _syncCatalog(
    MasterCatalogSpec spec, {
    required DateTime at,
  }) async {
    final MasterCatalogState? local = await stateDataSource.get(spec.catalog);

    final List<MasterCatalogVersion> versions;
    try {
      versions = await transport.getVersions();
    } catch (error) {
      return _recordFailure(local, spec.catalog, _describe(error), at);
    }

    final MasterCatalogVersion? server = _versionFor(versions, spec.catalog);
    if (server == null) {
      // No version row published for this catalog: nothing to download.
      return MasterCatalogSyncResult(
        catalog: spec.catalog,
        skipped: true,
        dataVersion: local?.dataVersion ?? 0,
      );
    }

    if (local != null &&
        local.hasApplied &&
        local.status == 'success' &&
        local.dataVersion == server.dataVersion) {
      return MasterCatalogSyncResult(
        catalog: spec.catalog,
        skipped: true,
        succeeded: true,
        dataVersion: server.dataVersion,
      );
    }

    final DateTime? since = local != null && local.sinceMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(local.sinceMs)
        : null;
    int offset = 0;
    int applied = 0;
    int batches = 0;
    int maxSince = local?.sinceMs ?? 0;
    bool hasMore = true;

    try {
      while (hasMore && batches < AppConstants.syncMaxPullBatches) {
        final MasterCatalogPage page = await transport.pullRows(
          spec.catalog,
          since: since,
          offset: offset,
          limit: AppConstants.syncPullBatchSize,
        );
        if (page.rows.isEmpty) {
          hasMore = false;
          break;
        }
        applied += await _applyBatch(spec, page.rows);
        for (final Map<String, Object?> row in page.rows) {
          final int rowMs = _toEpochMs(row[spec.updatedAtColumn]);
          if (rowMs > maxSince) maxSince = rowMs;
        }
        offset += page.rows.length;
        batches++;
        hasMore = page.hasMore;
        // Yield between batches so a large catalog does not freeze the UI.
        if (hasMore) await Future<void>.delayed(Duration.zero);
      }

      if (hasMore) {
        throw const MasterDataTransportException('max_batches_exceeded');
      }

      await stateDataSource.upsert(
        (local ?? MasterCatalogState(catalog: spec.catalog, updatedAt: at))
            .copyWith(
              dataVersion: server.dataVersion,
              schemaVersion: server.schemaVersion,
              sinceMs: maxSince,
              status: 'success',
              appliedAt: at,
              lastErrorAt: null,
              lastError: null,
              updatedAt: at,
              clearError: true,
            ),
      );
      return MasterCatalogSyncResult(
        catalog: spec.catalog,
        succeeded: true,
        applied: applied,
        batches: batches,
        dataVersion: server.dataVersion,
      );
    } catch (error) {
      return _recordFailure(local, spec.catalog, _describe(error), at);
    }
  }

  Future<MasterCatalogSyncResult> _recordFailure(
    MasterCatalogState? local,
    String catalog,
    String message,
    DateTime at,
  ) async {
    final MasterCatalogState base =
        local ?? MasterCatalogState(catalog: catalog, updatedAt: at);
    await stateDataSource.upsert(
      base.copyWith(
        status: 'failed',
        lastError: message,
        lastErrorAt: at,
        updatedAt: at,
      ),
    );
    SyncLog.warning(
      _logger,
      'MASTER_SYNC_FAILURE',
      'catalog=$catalog error=$message',
    );
    return MasterCatalogSyncResult(
      catalog: catalog,
      succeeded: false,
      dataVersion: base.dataVersion,
      error: message,
    );
  }

  /// Applies one page of cloud rows inside a single transaction. Returns the
  /// number of rows applied (rows whose FK parents were unresolvable are
  /// skipped, never half-inserted).
  Future<int> _applyBatch(
    MasterCatalogSpec spec,
    List<Map<String, Object?>> cloudRows,
  ) async {
    final sqflite.Database db = await database.database;
    return db.transaction((sqflite.Transaction txn) async {
      int applied = 0;
      for (final Map<String, Object?> cloudRow in cloudRows) {
        if (await _upsertRow(txn, spec, cloudRow)) applied++;
      }
      return applied;
    });
  }

  Future<bool> _upsertRow(
    sqflite.DatabaseExecutor txn,
    MasterCatalogSpec spec,
    Map<String, Object?> cloudRow,
  ) async {
    final Object? cloudId = cloudRow['id'];
    if (cloudId == null) return false;
    final String id = cloudId as String;

    final Map<String, Object?> local = <String, Object?>{};
    for (final MasterCatalogColumn column in spec.columns) {
      local[column.local] = _convert(spec, column.cloud, cloudRow[column.cloud]);
    }
    local['deleted_at'] = _toEpochOrNull(cloudRow['deleted_at']);
    local['row_version'] = (cloudRow['row_version'] as num?)?.toInt() ?? 0;
    for (final MapEntry<String, String> fk in spec.cloudForeignKeys.entries) {
      local[fk.key] = await _resolveFk(txn, fk.value, cloudRow[fk.key]);
    }

    // 1. Already known: update in place by uuid (local int id preserved).
    final List<Map<String, Object?>> byUuid = await txn.query(
      spec.localTable,
      columns: <String>['id'],
      where: 'uuid = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (byUuid.isNotEmpty) {
      await txn.update(
        spec.localTable,
        local,
        where: 'id = ?',
        whereArgs: <Object?>[byUuid.first['id']],
      );
      return true;
    }

    // 2. Adopt an existing seeded row in place (keeps its id and therefore the
    //    FK links from user data valid), stamping the cloud uuid on it.
    final String? naturalKeyLocal = spec.naturalKeyLocal;
    final String? naturalKeyCloud = spec.naturalKeyCloud;
    if (naturalKeyLocal != null && naturalKeyCloud != null) {
      final Object? key = cloudRow[naturalKeyCloud];
      if (key != null) {
        String where = '$naturalKeyLocal = ?';
        final List<Object?> args = <Object?>[key];
        if (spec.hybrid) {
          where = '$where AND user_id IS NULL';
        }
        final List<Map<String, Object?>> byKey = await txn.query(
          spec.localTable,
          columns: <String>['id'],
          where: where,
          whereArgs: args,
          limit: 1,
        );
        if (byKey.isNotEmpty) {
          await txn.update(
            spec.localTable,
            <String, Object?>{...local, 'uuid': id},
            where: 'id = ?',
            whereArgs: <Object?>[byKey.first['id']],
          );
          return true;
        }
      }
    }

    // 3. New row. Hybrid rows are master data, so user_id stays NULL.
    final Map<String, Object?> insert = <String, Object?>{...local, 'uuid': id};
    if (spec.hybrid) insert['user_id'] = null;
    try {
      await txn.insert(spec.localTable, insert);
      return true;
    } on sqflite.DatabaseException {
      // e.g. a child row whose FK parent is not yet present locally (the
      // parent catalog is always applied first, so this only happens for an
      // out-of-window reference). Skip rather than corrupt the graph.
      return false;
    }
  }

  Future<Object?> _resolveFk(
    sqflite.DatabaseExecutor txn,
    String localTable,
    Object? cloudUuid,
  ) async {
    if (cloudUuid == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      localTable,
      columns: <String>['id'],
      where: 'uuid = ?',
      whereArgs: <Object?>[cloudUuid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'];
  }

  Object? _convert(
    MasterCatalogSpec spec,
    String cloudColumn,
    Object? value,
  ) {
    if (value == null) return null;
    if (spec.timestampColumns.contains(cloudColumn)) {
      return _toEpochMs(value);
    }
    if (spec.booleanColumns.contains(cloudColumn)) {
      return value == true ? 1 : 0;
    }
    return value;
  }

  MasterCatalogVersion? _versionFor(
    List<MasterCatalogVersion> versions,
    String catalog,
  ) {
    for (final MasterCatalogVersion version in versions) {
      if (version.catalog == catalog) return version;
    }
    return null;
  }

  String _describe(Object error) {
    if (error is MasterDataTransportException) return error.message;
    return error.toString();
  }

  static int _toEpochMs(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is DateTime) return value.toUtc().millisecondsSinceEpoch;
    final DateTime? parsed = DateTime.tryParse(value.toString());
    return parsed?.toUtc().millisecondsSinceEpoch ?? 0;
  }

  static int? _toEpochOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is DateTime) return value.toUtc().millisecondsSinceEpoch;
    final DateTime? parsed = DateTime.tryParse(value.toString());
    return parsed?.toUtc().millisecondsSinceEpoch;
  }
}
