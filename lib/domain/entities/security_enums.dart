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
enum SyncStatus {
  pending,
  completed,
  failed;

  static SyncStatus fromName(String? value) {
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
