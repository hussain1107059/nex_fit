import 'dart:convert';

import '../../core/errors/app_exception.dart';
import '../services/backup/google_drive_backup_service.dart';
import '../../domain/repositories/app_preferences_repository.dart';
import '../../domain/repositories/backup_repository.dart';

/// Data layer implementation of [BackupRepository].
class BackupRepositoryImpl implements BackupRepository {
  const BackupRepositoryImpl({
    required this.backupService,
    required this.preferences,
  });

  final GoogleDriveBackupService backupService;
  final AppPreferencesRepository preferences;

  @override
  Future<bool> isBackupAvailable() => backupService.isAvailable();

  @override
  Future<DateTime?> getLastBackupTime() async {
    final DateTime? last = preferences.getLastBackupTime();
    return last;
  }

  @override
  Future<void> uploadBackup(String payload) async {
    final DateTime now = DateTime.now();
    final String fileName =
        '${GoogleDriveBackupService.filePrefix}_${now.toIso8601String().replaceAll(':', '')}.json';

    final Map<String, dynamic> envelope = <String, dynamic>{
      'version': 1,
      'createdAt': now.toIso8601String(),
      'platform': 'android',
      'payload': payload,
    };

    final String content = jsonEncode(envelope);
    await backupService.uploadBackup(content: content, fileName: fileName);
    await preferences.setLastBackupTime(now);
  }

  @override
  Future<String?> downloadBackup() async {
    final String? raw = await backupService.downloadLatestBackup();
    if (raw == null) return null;

    final Map<String, dynamic> envelope =
        jsonDecode(raw) as Map<String, dynamic>;
    final Object? payload = envelope['payload'];
    if (payload is String) return payload;

    throw const BackupException('backupCorrupted', code: 'corrupted');
  }

  @override
  Future<void> deleteBackup() async {
    final List<BackupFileInfo> backups = await backupService.listBackups();
    for (final BackupFileInfo backup in backups) {
      await backupService.deleteBackup(backup.id);
    }
  }

  @override
  Future<void> signOutFromDrive() async {
    await backupService.deleteAllBackups();
  }
}
