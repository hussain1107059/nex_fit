import '../../../domain/entities/security_enums.dart';
import '../../../domain/entities/sync_event.dart';

/// Outcome of pushing a single outbox event to the remote store.
class SyncPushResult {
  const SyncPushResult({
    required this.applied,
    this.conflict = false,
    this.serverRowVersion,
    this.serverData,
    this.serverUpdatedAt,
    this.lastError,
  });

  /// True when the remote store accepted the write.
  final bool applied;

  /// True when the remote row exists but its `row_version` differs from the
  /// event's `base_version` (optimistic concurrency conflict, Part 9).
  final bool conflict;

  /// The remote `row_version` after the write, when known.
  final int? serverRowVersion;

  /// Current remote row snapshot captured on a conflict (used to build the
  /// durable conflict record, PROMPT 19). Empty when the server row is gone.
  final Map<String, Object?>? serverData;

  /// The remote row's `updated_at` on a conflict, when available.
  final DateTime? serverUpdatedAt;

  /// Machine-readable failure code (e.g. `validation_error`, `unsupported`).
  final String? lastError;

  bool get failed => !applied && !conflict;
}

/// A single remote change pulled from `sync_changes` (Part 10).
class SyncChange {
  const SyncChange({
    required this.cursorId,
    required this.cloudTable,
    required this.recordId,
    required this.operation,
    required this.payload,
  });

  /// The monotonic `sync_changes.id` used as the pull cursor.
  final int cursorId;

  /// Cloud table name (e.g. `weight_logs`); mapped locally via the registry.
  final String cloudTable;

  /// Cloud `record_id` (the row's `uuid`).
  final String recordId;

  /// INSERT / UPDATE / DELETE.
  final SyncOperation operation;

  /// JSONB row snapshot as decoded map, or empty for DELETE.
  final Map<String, Object?> payload;

  bool get isDelete => operation == SyncOperation.delete;
}

/// One page of pulled changes plus the cursor to continue from (Part 10).
class SyncPullBatch {
  const SyncPullBatch({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<SyncChange> changes;
  final int nextCursor;
  final bool hasMore;
}

/// Thrown by [SyncTransport] implementations for network / protocol failures.
class SyncTransportException implements Exception {
  const SyncTransportException(this.message, {this.retryable = true});

  final String message;

  /// When false the failure is permanent (auth expired, validation) and the
  /// engine must not keep retrying blindly.
  final bool retryable;

  @override
  String toString() => 'SyncTransportException($message)';
}

/// Optional cloud transport for the two-way sync engine.
///
/// An implementation pushes outbox events to the remote store (Part 7) and
/// pulls `sync_changes` rows back to the local database (Part 10). When no
/// transport is configured or [isReady] is false the engine runs offline-first
/// and acknowledges every event locally.
abstract interface class SyncTransport {
  /// The transport identity used in structured logs (e.g. `supabase`).
  String get name;

  /// Whether the transport can currently talk to the remote store.
  bool get isReady;

  /// Pushes [event] to the remote store. Returns an [SyncPushResult]; throws
  /// [SyncTransportException] for network/protocol failures.
  Future<SyncPushResult> push(SyncEvent event);

  /// Pulls one page of changes for [userId] that occurred after [cursor].
  /// Returns the next cursor; callers persist it only after the batch applies
  /// to the local database (Part 11).
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit,
  });
}
