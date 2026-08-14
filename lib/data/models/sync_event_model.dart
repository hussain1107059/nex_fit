import '../../domain/entities/security_enums.dart';
import '../../domain/entities/sync_event.dart';
import 'model_codec.dart';

/// Maps [SyncEvent] to and from rows in the `sync_event` table.
class SyncEventModel {
  SyncEventModel._();

  static const String table = 'sync_event';

  static Map<String, Object?> toMap(SyncEvent event) {
    return <String, Object?>{
      'id': event.id,
      'user_id': event.userId,
      'entity': event.entity,
      'entity_id': event.entityId,
      'operation': event.operation.name,
      'payload': event.payload,
      'event_uuid': event.eventUuid,
      'device_id': event.deviceId,
      'base_version': event.baseVersion,
      'status': event.status.name,
      'retry_count': event.retryCount,
      'conflict_strategy': event.conflictStrategy.name,
      'next_retry_at': ModelCodec.epochMs(event.nextRetryAt),
      'created_at': ModelCodec.epochMs(event.createdAt),
      'updated_at': ModelCodec.epochMs(event.updatedAt),
      'synced_at': ModelCodec.epochMs(event.syncedAt),
      'last_error': event.lastError,
    };
  }

  static SyncEvent fromMap(Map<String, Object?> row) {
    return SyncEvent(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      entity: row['entity'] as String,
      entityId: row['entity_id'] as String,
      operation: SyncOperation.fromName(row['operation'] as String?),
      payload: row['payload'] as String?,
      eventUuid: row['event_uuid'] as String?,
      deviceId: row['device_id'] as String?,
      baseVersion: ModelCodec.toInt(row['base_version']),
      status: SyncStatus.fromName(row['status'] as String?),
      retryCount: ModelCodec.toInt(row['retry_count']),
      conflictStrategy: SyncConflictStrategy.fromName(
        row['conflict_strategy'] as String?,
      ),
      nextRetryAt: ModelCodec.fromEpochMs(row['next_retry_at'] as int?),
      createdAt: ModelCodec.fromEpochMs(row['created_at'] as int?) ??
          DateTime.now(),
      updatedAt: ModelCodec.fromEpochMs(row['updated_at'] as int?) ??
          DateTime.now(),
      syncedAt: ModelCodec.fromEpochMs(row['synced_at'] as int?),
      lastError: row['last_error'] as String?,
    );
  }
}
