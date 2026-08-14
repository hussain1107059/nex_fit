import 'package:equatable/equatable.dart';

import 'security_enums.dart';

/// A single durable mutation recorded by the offline sync engine.
///
/// Every local Create/Update/Delete on a tracked entity produces a
/// [SyncEvent]. Events are persisted in the `sync_event` table and flow
/// through the pending -> processing -> completed/failed lifecycle, ready for
/// a cloud transport to consume.
class SyncEvent extends Equatable {
  const SyncEvent({
    this.id,
    required this.userId,
    required this.entity,
    required this.entityId,
    required this.operation,
    this.payload,
    this.eventUuid,
    this.deviceId,
    this.baseVersion = 0,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
    this.conflictStrategy = SyncConflictStrategy.latestWins,
    this.nextRetryAt,
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

  /// Stable idempotency key generated once when the event is first queued and
  /// reused for every retry so a duplicate remote write is impossible.
  final String? eventUuid;

  /// The device that produced this event (see `DeviceIdService`).
  final String? deviceId;

  /// The local `row_version` the mutation was based on. Used by the push
  /// transport for optimistic conflict detection (`0` means "create").
  final int baseVersion;
  final SyncStatus status;
  final int retryCount;
  final SyncConflictStrategy conflictStrategy;

  /// Earliest allowed retry time for backoff. `null` = eligible now.
  final DateTime? nextRetryAt;
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
    String? eventUuid,
    String? deviceId,
    int? baseVersion,
    SyncStatus? status,
    int? retryCount,
    SyncConflictStrategy? conflictStrategy,
    DateTime? nextRetryAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    String? lastError,
    bool clearError = false,
    bool clearNextRetryAt = false,
  }) {
    return SyncEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      eventUuid: eventUuid ?? this.eventUuid,
      deviceId: deviceId ?? this.deviceId,
      baseVersion: baseVersion ?? this.baseVersion,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      conflictStrategy: conflictStrategy ?? this.conflictStrategy,
      nextRetryAt: clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
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
        eventUuid,
        deviceId,
        baseVersion,
        status,
        retryCount,
        conflictStrategy,
        nextRetryAt,
        createdAt,
        updatedAt,
        syncedAt,
        lastError,
      ];
}
