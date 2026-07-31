import '../entities/backup_history.dart';

/// Contract for recording the user's backup attempts.
abstract interface class BackupHistoryRepository {
  Future<int> insert(BackupHistory history);

  Future<BackupHistory?> getById(int id);

  Future<List<BackupHistory>> getByUserId(String userId);

  Future<void> delete(int id);
}
