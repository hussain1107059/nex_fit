import 'package:equatable/equatable.dart';

import 'security_enums.dart';

/// A single durable mutation recorded by the offline sync engine.
///
/// Every local Create/Update/Delete on a tracked entity produces a
/// [SyncEvent]. Events are persisted in the `sync_event` table and flow
/// through the pending -> completed/failed lifecycle, ready for a future
/// cloud transport to consume.
class SyncEvent extends Equatable {
  const SyncEvent({
    this.id,
    required this.userId,
    required this.entity,
    required this.entityId,
    required this.operation,
    this.payload,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
    this.conflictStrategy = SyncConflictStrategy.latestWins,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
    this.lastError,
  });

  final int? id;
  final String userId;
  final String entity;
  final String entityId;
  final SyncOperation operation;
  final String? payload;
  final SyncStatus status;
  final int retryCount;
  final SyncConflictStrategy conflictStrategy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  final String? lastError;

  SyncEvent copyWith({
    int? id,
    String? userId,
    String? entity,
    String? entityId,
    SyncOperation? operation,
    String? payload,
    SyncStatus? status,
    int? retryCount,
    SyncConflictStrategy? conflictStrategy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      conflictStrategy: conflictStrategy ?? this.conflictStrategy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        entity,
        entityId,
        operation,
        payload,
        status,
        retryCount,
        conflictStrategy,
        createdAt,
        updatedAt,
        syncedAt,
        lastError,
      ];
}
