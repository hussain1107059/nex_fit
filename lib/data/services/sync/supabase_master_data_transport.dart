import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../supabase_options.dart';
import '../supabase/supabase_service.dart';
import 'master_data_contracts.dart';
import 'sync_log.dart';

/// Supabase-backed [MasterDataTransport].
///
/// Reads `public.master_data_versions` for the version cursors and pulls rows
/// from each catalog table with a deterministic `id`-ordered, offset-based
/// page. Hybrid catalogs (foods / exercises / goal_templates) are filtered to
/// the `user_id IS NULL` master rows only, and the incremental pull anchors on
/// the client's high-water mark with `updated_at >= since` so a bulk publish
/// never loses rows that share an old timestamp. Master data is SELECT-only;
/// there are no write paths here.
class SupabaseMasterDataTransport implements MasterDataTransport {
  SupabaseMasterDataTransport({
    required this.service,
    Logger? logger,
  }) : _logger = logger ?? Logger('SupabaseMasterDataTransport');

  final SupabaseService service;
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
      throw const MasterDataTransportException('supabase_not_initialized');
    }
    return client;
  }

  @override
  Future<List<MasterCatalogVersion>> getVersions() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('master_data_versions')
          .select();
      return rows.map(_versionFromRow).toList();
    } on supabase.PostgrestException catch (error) {
      SyncLog.warning(
        _logger,
        'MASTER_VERSION_FAILURE',
        'code=${error.code} message=${error.message}',
      );
      throw MasterDataTransportException(
        'postgrest_${error.code}_${error.message}',
      );
    }
  }

  @override
  Future<MasterCatalogPage> pullRows(
    String catalog, {
    DateTime? since,
    int offset = 0,
    int limit = 100,
  }) async {
    final MasterCatalogSpec? spec = MasterCatalogRegistry.byCatalog(catalog);
    if (spec == null) {
      throw MasterDataTransportException(
        'unsupported_catalog_$catalog',
        retryable: false,
      );
    }

    try {
      // `dynamic` keeps the filter/transform builder chain legal across the
      // conditional steps of the supabase 2.x DSL. Filters (gte / isFilter)
      // must run FIRST while the builder is still a PostgrestFilterBuilder:
      // `.order()` downcasts it to a PostgrestTransformBuilder, which only
      // has transform methods, so any filter added after it would fail at
      // runtime with a NoSuchMethodError.
      dynamic query = _client.from(spec.cloudTable).select();
      if (since != null) {
        // >= so rows whose updated_at equals the stored watermark are
        // re-fetched at worst (idempotent) and never skipped.
        query = query.gte(
          spec.updatedAtColumn,
          since.toUtc().toIso8601String(),
        );
      }
      if (spec.hybrid && spec.cloudOwnerColumn != null) {
        // Only the developer's master rows are readable; user rows stay out
        // of the catalog flow entirely. Pure master tables (no owner column,
        // e.g. goal_templates) skip the filter.
        query = query.isFilter(spec.cloudOwnerColumn, null);
      }
      query = query.order('id');
      // Request limit+1 rows so `hasMore` is authoritative without an extra
      // round trip.
      final List<Map<String, dynamic>> rows =
          await query.range(offset, offset + limit) as List<Map<String, dynamic>>;
      final bool hasMore = rows.length > limit;
      final List<Map<String, Object?>> pageRows = hasMore
          ? rows.sublist(0, limit)
          : rows.cast<Map<String, Object?>>();
      return MasterCatalogPage(rows: pageRows, hasMore: hasMore);
    } on supabase.PostgrestException catch (error) {
      SyncLog.warning(
        _logger,
        'MASTER_PULL_FAILURE',
        'catalog=$catalog code=${error.code} message=${error.message}',
      );
      throw MasterDataTransportException(
        'postgrest_${error.code}_${error.message}',
      );
    }
  }

  MasterCatalogVersion _versionFromRow(Map<String, dynamic> row) {
    final String? rawUpdated = row['updated_at'] as String?;
    return MasterCatalogVersion(
      catalog: row['catalog'] as String,
      dataVersion: (row['data_version'] as num?)?.toInt() ?? 0,
      schemaVersion: (row['schema_version'] as num?)?.toInt() ?? 1,
      updatedAt: rawUpdated == null ? null : DateTime.tryParse(rawUpdated),
    );
  }
}