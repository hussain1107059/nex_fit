import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'app_database.dart';

/// Local watermark for one master catalog (the `master_catalog_state` table).
///
/// `data_version` mirrors `public.master_data_versions.data_version` and is
/// only advanced after a catalog download commits. `since` is the high-water
/// mark (max `updated_at` observed across applied rows) used for incremental
/// pulls, so a bulk publish that bumps the version but keeps older row
/// timestamps can never lose rows.
class MasterCatalogState {
  const MasterCatalogState({
    required this.catalog,
    this.dataVersion = 0,
    this.schemaVersion = 1,
    this.sinceMs = 0,
    this.status = 'pending',
    this.appliedAt,
    this.lastErrorAt,
    this.lastError,
    required this.updatedAt,
  });

  final String catalog;
  final int dataVersion;
  final int schemaVersion;

  /// Epoch-ms high-water mark for incremental pulls.
  final int sinceMs;

  /// 'pending' | 'success' | 'failed'.
  final String status;

  final DateTime? appliedAt;
  final DateTime? lastErrorAt;
  final String? lastError;
  final DateTime updatedAt;

  bool get hasApplied => appliedAt != null;

  MasterCatalogState copyWith({
    int? dataVersion,
    int? schemaVersion,
    int? sinceMs,
    String? status,
    DateTime? appliedAt,
    DateTime? lastErrorAt,
    String? lastError,
    DateTime? updatedAt,
    bool clearError = false,
  }) {
    return MasterCatalogState(
      catalog: catalog,
      dataVersion: dataVersion ?? this.dataVersion,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      sinceMs: sinceMs ?? this.sinceMs,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      lastErrorAt: lastErrorAt ?? this.lastErrorAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Read/write access to the `master_catalog_state` watermark table.
class MasterCatalogStateLocalDataSource {
  MasterCatalogStateLocalDataSource({required this.database});

  final AppDatabase database;

  Future<MasterCatalogState?> get(String catalog) async {
    final Database db = await database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'master_catalog_state',
      where: 'catalog = ?',
      whereArgs: <Object?>[catalog],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> upsert(MasterCatalogState state) async {
    final Database db = await database.database;
    await db.insert(
      'master_catalog_state',
      _toRow(state),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MasterCatalogState>> getAll() async {
    final Database db = await database.database;
    final List<Map<String, Object?>> rows =
        await db.query('master_catalog_state', orderBy: 'catalog ASC');
    return rows.map(_fromRow).toList();
  }

  static Map<String, Object?> _toRow(MasterCatalogState state) {
    return <String, Object?>{
      'catalog': state.catalog,
      'data_version': state.dataVersion,
      'schema_version': state.schemaVersion,
      'since': state.sinceMs,
      'status': state.status,
      'applied_at': state.appliedAt?.millisecondsSinceEpoch,
      'last_error_at': state.lastErrorAt?.millisecondsSinceEpoch,
      'last_error': state.lastError,
      'updated_at': state.updatedAt.millisecondsSinceEpoch,
    };
  }

  static MasterCatalogState _fromRow(Map<String, Object?> row) {
    final int? appliedAt = row['applied_at'] as int?;
    final int? lastErrorAt = row['last_error_at'] as int?;
    return MasterCatalogState(
      catalog: row['catalog'] as String,
      dataVersion: (row['data_version'] as int?) ?? 0,
      schemaVersion: (row['schema_version'] as int?) ?? 1,
      sinceMs: (row['since'] as int?) ?? 0,
      status: (row['status'] as String?) ?? 'pending',
      appliedAt: appliedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(appliedAt),
      lastErrorAt: lastErrorAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastErrorAt),
      lastError: row['last_error'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['updated_at'] as int?) ?? 0,
      ),
    );
  }
}