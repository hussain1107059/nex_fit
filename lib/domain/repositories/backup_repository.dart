import 'dart:typed_data';

import '../entities/remote_backup_file.dart';

/// Contract for Google Drive (AppData folder) backup & restore operations.
/// Implemented by [BackupRepositoryImpl] in the data layer.
abstract interface class BackupRepository {
  /// Whether the current user has a usable Drive session.
  Future<bool> isBackupAvailable();

  /// Uploads [bytes] into the app's private AppData folder and returns the
  /// created file.
  Future<RemoteBackupFile> uploadBytes({
    required Uint8List bytes,
    required String fileName,
  });

  /// Lists all backups stored in the AppData folder, newest first.
  Future<List<RemoteBackupFile>> listBackups();

  /// Downloads a single backup file by id.
  Future<Uint8List> downloadBytes(String fileId);

  Future<void> deleteBackup(String fileId);

  /// Removes every backup owned by the app.
  Future<void> deleteAllBackups();

  /// Signs the user out of Google Drive. The stored backups remain untouched.
  Future<void> signOutFromDrive();
}
