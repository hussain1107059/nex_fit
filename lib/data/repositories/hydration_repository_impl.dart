import '../../core/errors/app_exception.dart';
import '../../domain/entities/daily_hydration.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/water_history.dart';
import '../../domain/entities/water_log.dart';
import '../../domain/entities/water_statistics.dart';
import '../../domain/repositories/hydration_repository.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/repositories/user_fitness_profile_repository.dart';
import '../../domain/repositories/water_log_repository.dart';
import '../services/notifications/local_notification_service.dart';

/// SQLite + notifications backed implementation of [HydrationRepository].
class HydrationRepositoryImpl implements HydrationRepository {
  HydrationRepositoryImpl({
    required this._waterLogRepository,
    required this._userProfileRepository,
    required this._reminderRepository,
    required this._notificationService,
  });

  static const int _defaultGoalMl = 2000;
  static const int _maxSingleEntryMl = 5000;

  final WaterLogRepository _waterLogRepository;
  final UserFitnessProfileRepository _userProfileRepository;
  final ReminderRepository _reminderRepository;
  final LocalNotificationService _notificationService;

  @override
  Future<DailyHydration> loadDaily(String userId, DateTime date) async {
    final DateTime day = _dayStart(date);
    final DateTime next = day.add(const Duration(days: 1));
    final List<WaterLog> logs = await _waterLogRepository.getByDateRange(
      userId,
      day,
      next,
    )..sort((WaterLog a, WaterLog b) => a.loggedAt.compareTo(b.loggedAt));
    final int intakeMl = logs.fold(
      0,
      (int sum, WaterLog log) => sum + log.amountMl,
    );
    return DailyHydration(
      date: day,
      intakeMl: intakeMl,
      goalMl: await getGoal(userId),
      entries: logs,
    );
  }

  @override
  Future<WaterHistory> loadHistory(
    String userId,
    WaterHistoryPeriod period,
  ) async {
    final DateTime now = DateTime.now();
    final List<DateTime> bounds = _periodBounds(period, now);
    final DateTime start = bounds.first;
    final DateTime end = bounds.last;
    final List<WaterLog> logs = await _waterLogRepository.getByDateRange(
      userId,
      start,
      end.add(const Duration(days: 1)),
    );

    final List<WaterHistoryBucket> buckets = _bucketize(period, start, logs);
    return WaterHistory(
      period: period,
      start: start,
      end: end,
      buckets: buckets,
    );
  }

  @override
  Future<WaterStatistics> loadStatistics(String userId) async {
    final List<WaterLog> logs = await _waterLogRepository.getByUserId(userId);
    final int goal = await getGoal(userId);

    final Map<DateTime, int> byDay = <DateTime, int>{};
    for (final WaterLog log in logs) {
      final DateTime day = _dayStart(log.loggedAt);
      byDay[day] = (byDay[day] ?? 0) + log.amountMl;
    }

    final int totalMl = logs.fold(
      0,
      (int sum, WaterLog log) => sum + log.amountMl,
    );
    final int trackedDays = byDay.length;
    final int averageDailyMl = trackedDays == 0 ? 0 : totalMl ~/ trackedDays;

    DateTime? bestDay;
    int bestDayMl = 0;
    byDay.forEach((DateTime day, int ml) {
      if (ml > bestDayMl) {
        bestDayMl = ml;
        bestDay = day;
      }
    });

    final List<DateTime> goalMetDays = byDay.keys
        .where((DateTime day) => byDay[day]! >= goal)
        .toList()
      ..sort();

    return WaterStatistics(
      averageDailyMl: averageDailyMl,
      bestDay: bestDay,
      bestDayMl: bestDayMl,
      currentStreak: _currentStreak(goalMetDays, DateTime.now()),
      longestStreak: _longestStreak(goalMetDays),
      totalMl: totalMl,
      totalEntries: logs.length,
      trackedDays: trackedDays,
    );
  }

  @override
  Future<int> getGoal(String userId) async {
    final UserProfile? profile = await _userProfileRepository.getById(userId);
    return profile?.targetWaterMl ?? _defaultGoalMl;
  }

  @override
  Future<void> setGoal(String userId, int goalMl) async {
    if (goalMl < 500) throw const AppException('errorWaterGoalTooLow');
    if (goalMl > 10000) throw const AppException('errorWaterGoalTooHigh');
    final UserProfile? existing = await _userProfileRepository.getById(userId);
    final UserProfile updated = (existing ?? UserProfile(
      userId: userId,
      updatedAt: DateTime.now(),
    )).copyWith(targetWaterMl: goalMl, updatedAt: DateTime.now());
    await _userProfileRepository.upsert(updated);
  }

  @override
  Future<int> addEntry(
    String userId,
    int amountMl, {
    DateTime? date,
    String? note,
  }) async {
    _validateAmount(amountMl);
    final DateTime when = date ?? DateTime.now();
    final WaterLog log = WaterLog(
      userId: userId,
      amountMl: amountMl,
      loggedAt: when,
      createdAt: DateTime.now(),
      note: _cleanNote(note),
    );
    return _waterLogRepository.insert(log);
  }

  @override
  Future<void> updateEntry(WaterLog log) async {
    _validateAmount(log.amountMl);
    await _waterLogRepository.update(
      log.copyWith(note: _cleanNote(log.note)),
    );
  }

  @override
  Future<void> deleteEntry(int id) => _waterLogRepository.delete(id);

  @override
  Future<List<Reminder>> getReminders(String userId) =>
      _reminderRepository.getByUserId(userId);

  @override
  Future<int> addReminder(Reminder reminder) async {
    final int id = await _reminderRepository.insert(reminder);
    await _schedule(reminder.copyWith(id: id));
    await _notificationService.requestPermission();
    return id;
  }

  @override
  Future<void> updateReminder(Reminder reminder) async {
    await _reminderRepository.update(reminder);
    await _schedule(reminder);
  }

  @override
  Future<void> deleteReminder(int id) async {
    await _reminderRepository.delete(id);
    await _notificationService.cancelReminder(id);
  }

  @override
  Future<void> rescheduleAll(String userId) async {
    await _notificationService.initialize();
    await _notificationService.cancelAll();
    final List<Reminder> reminders = await _reminderRepository.getByUserId(
      userId,
    );
    for (final Reminder reminder in reminders) {
      if (!reminder.isEnabled) continue;
      await _schedule(reminder);
    }
  }

  Future<void> _schedule(Reminder reminder) async {
    await _notificationService.cancelReminder(reminder.id ?? 0);
    if (!reminder.isEnabled) return;
    await _notificationService.scheduleDaily(
      id: reminder.id ?? 0,
      title: reminder.title,
      body: reminder.body ?? '',
      time: reminder.time,
      daysOfWeek: reminder.daysOfWeek,
    );
  }

  List<DateTime> _periodBounds(WaterHistoryPeriod period, DateTime now) {
    final DateTime today = _dayStart(now);
    return switch (period) {
      WaterHistoryPeriod.daily => <DateTime>[
        today.subtract(const Duration(days: 13)),
        today,
      ],
      WaterHistoryPeriod.weekly => <DateTime>[
        _weekStart(today).subtract(const Duration(days: 7 * 7)),
        today,
      ],
      WaterHistoryPeriod.monthly => <DateTime>[
        DateTime(now.year, now.month - 11, 1),
        today,
      ],
      WaterHistoryPeriod.yearly => <DateTime>[
        DateTime(now.year - 4, 1, 1),
        today,
      ],
    };
  }

  List<WaterHistoryBucket> _bucketize(
    WaterHistoryPeriod period,
    DateTime start,
    List<WaterLog> logs,
  ) {
    final Map<DateTime, int> byStart = <DateTime, int>{};
    for (final WaterLog log in logs) {
      final DateTime bucketStart = _bucketStart(period, log.loggedAt);
      byStart[bucketStart] = (byStart[bucketStart] ?? 0) + log.amountMl;
    }

    final List<WaterHistoryBucket> buckets = <WaterHistoryBucket>[];
    DateTime cursor = _bucketStart(period, start);
    final DateTime end = _bucketStart(period, DateTime.now());
    while (!cursor.isAfter(end)) {
      buckets.add(
        WaterHistoryBucket(
          start: cursor,
          end: _bucketEnd(period, cursor),
          intakeMl: byStart[cursor] ?? 0,
        ),
      );
      cursor = _advanceBucket(period, cursor);
    }
    return buckets;
  }

  DateTime _bucketStart(WaterHistoryPeriod period, DateTime date) {
    return switch (period) {
      WaterHistoryPeriod.daily => _dayStart(date),
      WaterHistoryPeriod.weekly => _weekStart(date),
      WaterHistoryPeriod.monthly => DateTime(date.year, date.month, 1),
      WaterHistoryPeriod.yearly => DateTime(date.year, 1, 1),
    };
  }

  DateTime _bucketEnd(WaterHistoryPeriod period, DateTime start) {
    return _advanceBucket(period, start).subtract(const Duration(days: 1));
  }

  DateTime _advanceBucket(WaterHistoryPeriod period, DateTime cursor) {
    return switch (period) {
      WaterHistoryPeriod.daily => cursor.add(const Duration(days: 1)),
      WaterHistoryPeriod.weekly => cursor.add(const Duration(days: 7)),
      WaterHistoryPeriod.monthly => DateTime(
        cursor.year,
        cursor.month + 1,
        1,
      ),
      WaterHistoryPeriod.yearly => DateTime(cursor.year + 1, 1, 1),
    };
  }

  DateTime _weekStart(DateTime date) {
    final DateTime day = _dayStart(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  DateTime _dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

  int _currentStreak(List<DateTime> goalMetDays, DateTime now) {
    final Set<DateTime> set = goalMetDays.toSet();
    DateTime cursor = _dayStart(now);
    if (!set.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    int streak = 0;
    while (set.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _longestStreak(List<DateTime> goalMetDays) {
    if (goalMetDays.isEmpty) return 0;
    int longest = 1;
    int run = 1;
    for (int i = 1; i < goalMetDays.length; i++) {
      if (goalMetDays[i].difference(goalMetDays[i - 1]).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }
    return longest;
  }

  void _validateAmount(int amountMl) {
    if (amountMl <= 0) throw const AppException('errorWaterNegative');
    if (amountMl > _maxSingleEntryMl) {
      throw const AppException('errorWaterUnrealistic');
    }
  }

  String? _cleanNote(String? note) {
    if (note == null) return null;
    final String trimmed = note.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
