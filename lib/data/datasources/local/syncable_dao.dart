import 'package:sqflite/sqflite.dart' show Transaction;

import '../../../core/security/uuid_generator.dart';
import '../../../domain/entities/security_enums.dart';
import '../../services/sync/sync_event_recorder.dart';

/// Shared helpers for DAOs participating in offline two-way sync (PROMPT 11).
///
/// Every tracked mutation runs inside the same transaction as its outbox event
/// (`SyncEventRecorder.recordInTransaction`) so a failure rolls both back.
/// The DAO owns the four sync columns directly - `uuid` (cloud identity),
/// `created_at`, `updated_at` and `row_version` - while the domain entity keeps
/// its existing shape (method signatures and integer ids are preserved).
class SyncableDao {
  SyncableDao._();

  /// A fresh RFC 4122 v4 uuid used as the cloud `id` for a new local row.
  static String newUuid() => UuidGenerator.v4();

  /// Current epoch-ms timestamp for `created_at` / `updated_at` columns.
  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// The version a brand-new row starts at (PROMPT 11 INSERT contract).
  static const int firstRowVersion = 1;

  /// Enqueues a CREATE outbox event inside [txn] (atomic with the mutation).
  static Future<void> recordCreate(
    Transaction txn, {
    required String entity,
    required String entityId,
    required String userId,
  }) {
    return SyncEventRecorder.recordInTransaction(
      txn,
      entity: entity,
      entityId: entityId,
      operation: SyncOperation.create,
      userId: userId,
    );
  }

  /// Enqueues an UPDATE outbox event carrying the version the mutation was
  /// based on ([baseVersion]) for optimistic conflict detection.
  static Future<void> recordUpdate(
    Transaction txn, {
    required String entity,
    required String entityId,
    required String userId,
    required int baseVersion,
  }) {
    return SyncEventRecorder.recordInTransaction(
      txn,
      entity: entity,
      entityId: entityId,
      operation: SyncOperation.update,
      userId: userId,
      baseVersion: baseVersion,
    );
  }

  /// Enqueues a DELETE outbox event (soft-delete tombstone) inside [txn].
  static Future<void> recordDelete(
    Transaction txn, {
    required String entity,
    required String entityId,
    required String userId,
    required int baseVersion,
  }) {
    return SyncEventRecorder.recordInTransaction(
      txn,
      entity: entity,
      entityId: entityId,
      operation: SyncOperation.delete,
      userId: userId,
      baseVersion: baseVersion,
    );
  }
}