import 'package:equatable/equatable.dart';

/// Per-user two-way sync state (the `sync_state` table): the pull cursor,
/// initial-sync flag and last observed status.
///
/// The cursor is the monotonic `sync_changes.id` the user has consumed. It is
/// only advanced inside the same transaction that applies the pulled changes,
/// so a crash never loses or double-applies remote rows (Parts 10-12).
class SyncState extends Equatable {
  const SyncState({
    required this.userId,
    this.cursor = 0,
    this.initialSyncCompleted = false,
    this.lastSyncAt,
    this.status,
    this.masterVersions,
    required this.updatedAt,
  });

  final String userId;
  final int cursor;
  final bool initialSyncCompleted;
  final DateTime? lastSyncAt;

  /// Machine-readable last sync status (matches the UI `SyncUiStatus` names).
  final String? status;

  /// JSON snapshot of `master_data_versions` cursors (master catalog sync).
  final String? masterVersions;
  final DateTime updatedAt;

  bool get hasSynced => lastSyncAt != null;

  SyncState copyWith({
    int? cursor,
    bool? initialSyncCompleted,
    DateTime? lastSyncAt,
    String? status,
    String? masterVersions,
    DateTime? updatedAt,
  }) {
    return SyncState(
      userId: userId,
      cursor: cursor ?? this.cursor,
      initialSyncCompleted: initialSyncCompleted ?? this.initialSyncCompleted,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      status: status ?? this.status,
      masterVersions: masterVersions ?? this.masterVersions,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        cursor,
        initialSyncCompleted,
        lastSyncAt,
        status,
        masterVersions,
        updatedAt,
      ];
}
