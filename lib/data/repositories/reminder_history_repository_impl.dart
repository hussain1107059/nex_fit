import '../../domain/entities/common_enums.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_history.dart';
import '../../domain/entities/reminder_statistics.dart';
import '../../domain/repositories/reminder_history_repository.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/local/reminder_history_local_data_source.dart';
import '../services/notifications/reminder_schedule.dart';

/// SQLite backed implementation of [ReminderHistoryRepository].
class ReminderHistoryRepositoryImpl implements ReminderHistoryRepository {
  ReminderHistoryRepositoryImpl({
    required this._dataSource,
    required this._reminderRepository,
  });

  final ReminderHistoryLocalDataSource _dataSource;
  final ReminderRepository _reminderRepository;

  @override
  Future<int> insert(ReminderHistory history) => _dataSource.insert(history);

  @override
  Future<void> insertAll(List<ReminderHistory> history) =>
      _dataSource.insertAll(history);

  @override
  Future<void> update(ReminderHistory history) => _dataSource.update(history);

  @override
  Future<List<ReminderHistory>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<ReminderHistory>> getByReminderId(int reminderId) =>
      _dataSource.getByReminderId(reminderId);

  @override
  Future<List<ReminderHistory>> getByStatus(
    String userId,
    ReminderHistoryStatus status,
  ) => _dataSource.getByStatus(userId, status);

  @override
  Future<List<DateTime>> getScheduledFor(int reminderId) =>
      _dataSource.getScheduledFor(reminderId);

  @override
  Future<void> deleteByReminderId(int reminderId) =>
      _dataSource.deleteByReminderId(reminderId);

  @override
  Future<int> syncMissed(String userId, DateTime now) async {
    final List<Reminder> reminders = await _reminderRepository.getByUserId(
      userId,
    );
    final List<ReminderHistory> missed = <ReminderHistory>[];
    for (final Reminder reminder in reminders) {
      final List<DateTime> recorded =
          await _dataSource.getScheduledFor(reminder.id ?? 0);
      final Set<DateTime> recordedSet = recorded.toSet();

      final DateTime from = reminder.lastTriggeredAt ?? reminder.createdAt;
      if (from.isAfter(now)) continue;

      final List<DateTime> occurrences = reminderOccurrences(
        reminder,
        from,
        now,
      );
      final List<ReminderHistory> fresh = <ReminderHistory>[];
      for (final DateTime scheduled in occurrences) {
        if (recordedSet.contains(scheduled)) continue;
        fresh.add(
          ReminderHistory(
            userId: userId,
            reminderId: reminder.id,
            status: ReminderHistoryStatus.missed,
            scheduledFor: scheduled,
            createdAt: now,
          ),
        );
      }
      if (fresh.isNotEmpty) {
        await _dataSource.insertAll(fresh);
        missed.addAll(fresh);
        final DateTime last = fresh.last.scheduledFor;
        await _reminderRepository.update(
          reminder.copyWith(
            lastTriggeredAt: last,
            updatedAt: now,
          ),
        );
      }
    }
    return missed.length;
  }

  @override
  Future<ReminderStatistics> getStatistics(String userId) async {
    final List<ReminderHistory> all = await _dataSource.getByUserId(userId);
    final List<Reminder> reminders = await _reminderRepository.getByUserId(
      userId,
    );
    final Map<int, Reminder> byId = <int, Reminder>{
      for (final Reminder r in reminders)
        if (r.id != null) r.id!: r,
    };

    int completed = 0;
    int missed = 0;
    int skipped = 0;
    final Map<int, int> completedByReminder = <int, int>{};
    for (final ReminderHistory entry in all) {
      switch (entry.status) {
        case ReminderHistoryStatus.completed:
          completed++;
          final int? id = entry.reminderId;
          if (id != null) {
            completedByReminder[id] = (completedByReminder[id] ?? 0) + 1;
          }
        case ReminderHistoryStatus.missed:
          missed++;
        case ReminderHistoryStatus.skipped:
          skipped++;
      }
    }

    final int fired = completed + missed;
    final double completionRate = fired == 0
        ? 0
        : (completed / fired * 100).clamp(0, 100).toDouble();
    final double missedRate = fired == 0
        ? 0
        : (missed / fired * 100).clamp(0, 100).toDouble();

    int mostCompleted = 0;
    Reminder? mostSuccessful;
    for (final MapEntry<int, int> entry in completedByReminder.entries) {
      if (entry.value > mostCompleted) {
        mostCompleted = entry.value;
        mostSuccessful = byId[entry.key];
      }
    }

    return ReminderStatistics(
      total: all.length,
      completed: completed,
      missed: missed,
      skipped: skipped,
      completionRate: completionRate,
      missedRate: missedRate,
      mostSuccessfulReminder: mostSuccessful,
      mostSuccessfulCompleted: mostCompleted,
    );
  }
}
