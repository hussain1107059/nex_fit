import '../../domain/entities/sync_state.dart';
import 'model_codec.dart';

/// Maps [SyncState] to and from rows in the `sync_state` table.
class SyncStateModel {
  SyncStateModel._();

  static const String table = 'sync_state';

  static Map<String, Object?> toMap(SyncState state) {
    return <String, Object?>{
      'user_id': state.userId,
      'cursor': state.cursor,
      'initial_sync_completed': state.initialSyncCompleted ? 1 : 0,
      'last_sync_at': ModelCodec.epochMs(state.lastSyncAt),
      'status': state.status,
      'master_versions': state.masterVersions,
      'updated_at': ModelCodec.epochMs(state.updatedAt),
    };
  }

  static SyncState fromMap(Map<String, Object?> row) {
    return SyncState(
      userId: row['user_id'] as String,
      cursor: ModelCodec.toInt(row['cursor']),
      initialSyncCompleted: (row['initial_sync_completed'] as num?) == 1,
      lastSyncAt: ModelCodec.fromEpochMs(row['last_sync_at'] as int?),
      status: row['status'] as String?,
      masterVersions: row['master_versions'] as String?,
      updatedAt: ModelCodec.fromEpochMs(row['updated_at'] as int?) ??
          DateTime.now(),
    );
  }
}
