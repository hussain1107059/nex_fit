import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/local/reminder_local_data_source.dart';

/// SQLite backed implementation of [ReminderRepository].
class ReminderRepositoryImpl implements ReminderRepository {
  const ReminderRepositoryImpl(this._dataSource);

  final ReminderLocalDataSource _dataSource;

  @override
  Future<int> insert(Reminder reminder) => _dataSource.insert(reminder);

  @override
  Future<void> update(Reminder reminder) => _dataSource.update(reminder);

  @override
  Future<Reminder?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<Reminder>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<Reminder>> getEnabled(String userId) =>
      _dataSource.getEnabled(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
