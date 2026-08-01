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

  @override
  Future<int> duplicate(int id) async {
    final Reminder? source = await _dataSource.getById(id);
    if (source == null) {
      throw StateError('Cannot duplicate unknown reminder: $id');
    }
    final DateTime now = DateTime.now();
    return _dataSource.insert(
      source.copyWith(
        id: null,
        title: '${source.title} (copy)',
        isEnabled: true,
        lastTriggeredAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<bool> hasDuplicate(Reminder candidate) async {
    return await findDuplicate(candidate) != null;
  }

  @override
  Future<Reminder?> findDuplicate(Reminder candidate) async {
    final List<Reminder> existing = await _dataSource.getByUserId(
      candidate.userId,
    );
    for (final Reminder other in existing) {
      if (other.id != candidate.id && candidate.isDuplicateOf(other)) {
        return other;
      }
    }
    return null;
  }
}
