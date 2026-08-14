import 'package:sqflite/sqflite.dart' show Transaction;

import '../entities/sync_state.dart';

/// Contract for the per-user pull cursor state.
abstract interface class SyncStateRepository {
  Future<SyncState?> getByUserId(String userId);

  Future<void> upsert(SyncState state);

  /// Advances the cursor inside an existing transaction (see Part 11).
  Future<void> upsertInTransaction(Transaction txn, SyncState state);
}
