import 'package:equatable/equatable.dart';

import 'security_enums.dart';

/// Lifecycle of a durable conflict record (PROMPT 19).
enum ConflictResolutionStatus {
  /// Detected, awaiting resolution (manual-merge strategy).
  pending,

  /// The server revision won (default resolution); local data is preserved in
  /// the record for recovery/review but the remote row is authoritative.
  serverWon,

  /// Manually resolved (user picked a side in a later phase).
  resolved;

  static ConflictResolutionStatus fromName(String? value) {
    return ConflictResolutionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ConflictResolutionStatus.pending,
    );
  }
}

/// A durable record of a single optimistic-lock conflict (PROMPT 19).
///
/// Captured when a push is rejected because the remote `row_version` moved past
/// the event's `base_version`. Both sides are snapshotted so the conflicting
/// local data is never discarded and can be reviewed/recovered later.
class SyncConflictRecord extends Equatable {
  const SyncConflictRecord({
    this.id,
    required this.userId,
    required this.entity,
    required this.recordUuid,
    this.localData,
    this.serverData,
    this.localVersion = 0,
    this.serverVersion = 0,
    this.localUpdatedAt,
    this.serverUpdatedAt,
    required this.detectedAt,
    this.status = ConflictResolutionStatus.pending,
    this.strategy = SyncConflictStrategy.latestWins,
    this.resolvedAt,
  });

  final int? id;
  final String userId;

  /// Local table / cloud entity name (e.g. `weight_log`).
  final String entity;

  /// The conflicting row's cloud uuid (the `record_id`).
  final String recordUuid;

  /// JSON snapshot of the local row at conflict time (never discarded).
  final String? localData;

  /// JSON snapshot of the server row at conflict time.
  final String? serverData;

  /// The `row_version` the local edit was based on.
  final int localVersion;

  /// The remote `row_version` that won.
  final int serverVersion;

  final DateTime? localUpdatedAt;
  final DateTime? serverUpdatedAt;
  final DateTime detectedAt;
  final ConflictResolutionStatus status;
  final SyncConflictStrategy strategy;
  final DateTime? resolvedAt;

  @override
  List<Object?> get props => [
        id,
        userId,
        entity,
        recordUuid,
        localData,
        serverData,
        localVersion,
        serverVersion,
        localUpdatedAt,
        serverUpdatedAt,
        detectedAt,
        status,
        strategy,
        resolvedAt,
      ];
}