/// Contract for Google Drive backup & restore operations.
/// Implemented by [BackupRepositoryImpl] in the data layer.
abstract interface class BackupRepository {
  Future<bool> isBackupAvailable();

  Future<DateTime?> getLastBackupTime();

  Future<void> uploadBackup(String payload);

  Future<String?> downloadBackup();

  Future<void> deleteBackup();

  Future<void> signOutFromDrive();
}
