import '../../domain/entities/backup_history.dart';
import '../../domain/repositories/backup_history_repository.dart';
import '../datasources/local/backup_history_local_data_source.dart';

/// SQLite backed implementation of [BackupHistoryRepository].
class BackupHistoryRepositoryImpl implements BackupHistoryRepository {
  const BackupHistoryRepositoryImpl(this._dataSource);

  final BackupHistoryLocalDataSource _dataSource;

  @override
  Future<int> insert(BackupHistory history) => _dataSource.insert(history);

  @override
  Future<BackupHistory?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<BackupHistory>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
