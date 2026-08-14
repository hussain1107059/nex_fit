import 'package:sqflite/sqflite.dart' show Transaction;

import '../../domain/entities/sync_state.dart';
import '../../domain/repositories/sync_state_repository.dart';
import '../datasources/local/sync_state_local_data_source.dart';

/// SQLite backed implementation of [SyncStateRepository].
class SyncStateRepositoryImpl implements SyncStateRepository {
  const SyncStateRepositoryImpl(this._dataSource);

  final SyncStateLocalDataSource _dataSource;

  @override
  Future<SyncState?> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<void> upsert(SyncState state) => _dataSource.upsert(state);

  @override
  Future<void> upsertInTransaction(Transaction txn, SyncState state) =>
      _dataSource.upsertInTransaction(txn, state);
}