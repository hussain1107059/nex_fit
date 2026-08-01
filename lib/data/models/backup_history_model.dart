import '../../domain/entities/backup_history.dart';
import '../../domain/entities/common_enums.dart';
import 'model_codec.dart';

/// Maps [BackupHistory] to and from rows in the `backup_history` table.
class BackupHistoryModel {
  BackupHistoryModel._();

  static const String table = 'backup_history';

  static Map<String, Object?> toMap(BackupHistory history) {
    return <String, Object?>{
      'id': history.id,
      'user_id': history.userId,
      'backup_type': history.backupType.name,
      'backup_size_bytes': history.backupSizeBytes,
      'file_name': history.fileName,
      'file_id': history.fileId,
      'status': history.status.name,
      'error_message': history.errorMessage,
      'duration_ms': history.durationMs,
      'app_version': history.appVersion,
      'database_version': history.databaseVersion,
      'device_name': history.deviceName,
      'checksum': history.checksum,
      'encrypted': ModelCodec.boolToInt(history.encrypted),
      'created_at': ModelCodec.epochMs(history.createdAt),
    };
  }

  static BackupHistory fromMap(Map<String, Object?> row) {
    return BackupHistory(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      backupType: BackupType.fromName(row['backup_type'] as String?),
      backupSizeBytes: row['backup_size_bytes'] as int?,
      fileName: row['file_name'] as String?,
      fileId: row['file_id'] as String?,
      status: BackupStatus.fromName(row['status'] as String?),
      errorMessage: row['error_message'] as String?,
      durationMs: row['duration_ms'] as int?,
      appVersion: row['app_version'] as String?,
      databaseVersion: row['database_version'] as int?,
      deviceName: row['device_name'] as String?,
      checksum: row['checksum'] as String?,
      encrypted: ModelCodec.intToBool(row['encrypted']),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }
}
