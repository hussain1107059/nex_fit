// Shared enums for the security, encryption & offline sync layer.

/// The kind of mutation a sync event records.
enum SyncOperation {
  create,
  update,
  delete;

  static SyncOperation fromName(String? value) {
    return SyncOperation.values.firstWhere(
      (operation) => operation.name == value,
      orElse: () => SyncOperation.create,
    );
  }
}

/// Lifecycle state of a sync event inside the offline queue.
///
/// The statuses mirror the outbox protocol: PENDING -> PROCESSING -> SUCCESS,
/// with FAILED_RETRYABLE (backoff, will retry) and FAILED_PERMANENT (terminal).
/// `failed` is the pre-v16 legacy name for a permanent failure and is read as
/// [SyncStatus.failedPermanent].
enum SyncStatus {
  /// Queued and eligible to run (immediately or once `next_retry_at` passes).
  pending,

  /// In-flight on a device. Events left in this state are reclaimed on startup
  /// by [SyncEngine.resetStuckProcessingEvents] (see `sync_state` docs).
  processing,

  /// Successfully delivered and acknowledged by the remote store.
  completed,

  /// Transient failure (network / 5xx / auth). Retried with exponential
  /// backoff up to `AppConstants.syncMaxRetries`.
  failedRetryable,

  /// Terminal failure. Requires manual intervention; never auto-retried.
  failedPermanent,

  /// Legacy alias persisted by pre-foundation versions. Treated as a
  /// permanent failure everywhere.
  failed;

  bool get isFinal => this == completed || this == failedPermanent;

  bool get isRetryable =>
      this == pending || this == failedRetryable || this == processing;

  static SyncStatus fromName(String? value) {
    if (value == 'failed') return SyncStatus.failedPermanent;
    return SyncStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SyncStatus.pending,
    );
  }
}

/// How a conflict between a local change and the remote source is resolved.
enum SyncConflictStrategy {
  latestWins,
  manualMerge;

  static SyncConflictStrategy fromName(String? value) {
    return SyncConflictStrategy.values.firstWhere(
      (strategy) => strategy.name == value,
      orElse: () => SyncConflictStrategy.latestWins,
    );
  }
}

/// Subsystem that produced an error record.
enum ErrorCategory {
  auth,
  sync,
  notification,
  backup,
  database,
  ui;

  static ErrorCategory fromName(String? value) {
    return ErrorCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => ErrorCategory.ui,
    );
  }
}

/// Outcome of a session validation.
enum SessionStatus {
  valid,
  expired,
  deviceChanged,
  none;

  static SessionStatus fromName(String? value) {
    return SessionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SessionStatus.none,
    );
  }
}

/// Result of the SQLite integrity check.
enum DatabaseHealthStatus {
  healthy,
  corrupt;

  static DatabaseHealthStatus fromName(String? value) {
    return DatabaseHealthStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => DatabaseHealthStatus.corrupt,
    );
  }
}
