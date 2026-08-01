import 'dart:typed_data';

import '../../domain/entities/remote_backup_file.dart';
import '../../domain/repositories/backup_repository.dart';
import '../services/backup/google_drive_backup_service.dart';

/// Data layer implementation of [BackupRepository].
class BackupRepositoryImpl implements BackupRepository {
  const BackupRepositoryImpl({
    required this.backupService,
  });

  final GoogleDriveBackupService backupService;

  @override
  Future<bool> isBackupAvailable() => backupService.isAvailable();

  @override
  Future<RemoteBackupFile> uploadBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final BackupFileInfo file = await backupService.uploadBytes(
      bytes: bytes,
      fileName: fileName,
    );
    return _mapFile(file);
  }

  @override
  Future<List<RemoteBackupFile>> listBackups() async {
    final List<BackupFileInfo> files = await backupService.listBackups();
    return files.map(_mapFile).toList();
  }

  @override
  Future<Uint8List> downloadBytes(String fileId) =>
      backupService.downloadBytes(fileId);

  @override
  Future<void> deleteBackup(String fileId) =>
      backupService.deleteBackup(fileId);

  @override
  Future<void> deleteAllBackups() => backupService.deleteAllBackups();

  @override
  Future<void> signOutFromDrive() => backupService.signInService.signOut();

  RemoteBackupFile _mapFile(BackupFileInfo file) {
    return RemoteBackupFile(
      id: file.id,
      name: file.name,
      createdAt: file.createdAt,
      sizeBytes: file.sizeBytes,
    );
  }
}
