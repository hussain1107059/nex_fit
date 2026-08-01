import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/errors/app_exception.dart';
import 'package:nexfit/data/repositories/hydration_repository_impl.dart';
import 'package:nexfit/data/services/notifications/local_notification_service.dart';
import 'package:nexfit/domain/entities/daily_hydration.dart';
import 'package:nexfit/domain/entities/reminder.dart';
import 'package:nexfit/domain/entities/user_profile.dart';
import 'package:nexfit/domain/entities/water_history.dart';
import 'package:nexfit/domain/entities/water_log.dart';
import 'package:nexfit/domain/entities/water_statistics.dart';
import 'package:nexfit/domain/repositories/reminder_repository.dart';
import 'package:nexfit/domain/repositories/user_fitness_profile_repository.dart';
import 'package:nexfit/domain/repositories/water_log_repository.dart';

class _MemoryWaterLogRepository implements WaterLogRepository {
  final List<WaterLog> logs = <WaterLog>[];
  int _nextId = 1;

  @override
  Future<int> insert(WaterLog log) async {
    final WaterLog copy = log.copyWith(id: _nextId++);
    logs.add(copy);
    return copy.id!;
  }

  @override
  Future<void> update(WaterLog log) async {
    final int index = logs.indexWhere((WaterLog l) => l.id == log.id);
    if (index >= 0) logs[index] = log;
  }

  @override
  Future<WaterLog?> getById(int id) async {
    for (final WaterLog log in logs) {
      if (log.id == id) return log;
    }
    return null;
  }

  @override
  Future<List<WaterLog>> getByUserId(String userId) async {
    return logs.where((WaterLog l) => l.userId == userId).toList();
  }

  @override
  Future<List<WaterLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    return logs
        .where(
          (WaterLog l) =>
              l.userId == userId &&
              !l.loggedAt.isBefore(start) &&
              l.loggedAt.isBefore(end),
        )
        .toList();
  }

  @override
  Future<void> delete(int id) async {
    logs.removeWhere((WaterLog l) => l.id == id);
  }
}

class _MemoryReminderRepository implements ReminderRepository {
  final List<Reminder> reminders = <Reminder>[];

  @override
  Future<int> insert(Reminder reminder) async {
    reminders.add(reminder);
    return reminders.length;
  }

  @override
  Future<void> update(Reminder reminder) async {}

  @override
  Future<Reminder?> getById(int id) async => null;

  @override
  Future<List<Reminder>> getByUserId(String userId) async =>
      reminders.where((Reminder r) => r.userId == userId).toList();

  @override
  Future<List<Reminder>> getEnabled(String userId) async => const <Reminder>[];

  @override
  Future<void> delete(int id) async {}

  @override
  Future<int> duplicate(int id) async => id;

  @override
  Future<bool> hasDuplicate(Reminder candidate) async => false;

  @override
  Future<Reminder?> findDuplicate(Reminder candidate) async => null;
}

class _MemoryUserProfileRepository implements UserFitnessProfileRepository {
  UserProfile? profile;

  @override
  Future<void> upsert(UserProfile profile) async => this.profile = profile;

  @override
  Future<UserProfile?> getById(String userId) async => profile;

  @override
  Future<void> delete(String userId) async => profile = null;
}

void main() {
  late _MemoryWaterLogRepository waterLogs;
  late _MemoryReminderRepository reminders;
  late _MemoryUserProfileRepository profiles;
  late HydrationRepositoryImpl repository;

  setUp(() {
    waterLogs = _MemoryWaterLogRepository();
    reminders = _MemoryReminderRepository();
    profiles = _MemoryUserProfileRepository();
    repository = HydrationRepositoryImpl(
      waterLogRepository: waterLogs,
      userProfileRepository: profiles,
      reminderRepository: reminders,
      notificationService: LocalNotificationService.instance,
    );
  });

  WaterLog makeLog({
    int amountMl = 250,
    DateTime? loggedAt,
    String? note,
  }) {
    return WaterLog(
      userId: 'user-1',
      amountMl: amountMl,
      loggedAt: loggedAt ?? DateTime.now(),
      createdAt: DateTime.now(),
      note: note,
    );
  }

  group('loadDaily', () {
    test('aggregates intake for the requested day', () async {
      final DateTime day = DateTime(2026, 8, 2, 10);
      await waterLogs.insert(makeLog(amountMl: 250, loggedAt: day));
      await waterLogs.insert(makeLog(amountMl: 250, loggedAt: day));

      final DailyHydration daily = await repository.loadDaily('user-1', day);

      expect(daily.intakeMl, 500);
      expect(daily.entries, hasLength(2));
      expect(daily.goalMl, 2000);
    });

    test('defaults to the shared goal when no profile target exists', () async {
      final DailyHydration daily = await repository.loadDaily(
        'user-1',
        DateTime(2026, 8, 2),
      );
      expect(daily.goalMl, 2000);
      expect(daily.intakeMl, 0);
    });
  });

  group('loadStatistics', () {
    test('is empty when there are no entries', () async {
      final WaterStatistics stats = await repository.loadStatistics('user-1');

      expect(stats.totalEntries, 0);
      expect(stats.totalMl, 0);
      expect(stats.trackedDays, 0);
      expect(stats.currentStreak, 0);
    });

    test('computes averages, best day and streaks', () async {
      await profiles.upsert(
        UserProfile(userId: 'user-1', targetWaterMl: 1000, updatedAt: DateTime.now()),
      );
      final DateTime today = DateTime(2026, 8, 2);
      final DateTime yesterday = DateTime(2026, 8, 1);
      // Two consecutive goal-met days plus one older day below goal.
      await waterLogs.insert(makeLog(amountMl: 600, loggedAt: today));
      await waterLogs.insert(makeLog(amountMl: 600, loggedAt: today));
      await waterLogs.insert(makeLog(amountMl: 1000, loggedAt: yesterday));
      await waterLogs.insert(makeLog(amountMl: 100, loggedAt: DateTime(2026, 7, 30)));

      final WaterStatistics stats = await repository.loadStatistics('user-1');

      expect(stats.totalEntries, 4);
      expect(stats.totalMl, 2300);
      expect(stats.trackedDays, 3);
      expect(stats.averageDailyMl, 766);
      expect(stats.bestDay, today);
      expect(stats.bestDayMl, 1200);
      expect(stats.currentStreak, 2);
      expect(stats.longestStreak, 2);
    });
  });

  group('addEntry', () {
    test('inserts an entry with a cleaned note', () async {
      final int id = await repository.addEntry(
        'user-1',
        300,
        note: '  post workout  ',
      );

      expect(id, isNonZero);
      expect(waterLogs.logs, hasLength(1));
      expect(waterLogs.logs.single.note, 'post workout');
    });

    test('rejects a negative amount', () async {
      expect(
        () => repository.addEntry('user-1', -1),
        throwsA(isA<AppException>()),
      );
    });

    test('rejects an unrealistic amount', () async {
      expect(
        () => repository.addEntry('user-1', 5001),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('setGoal', () {
    test('upserts the water target on the profile', () async {
      await repository.setGoal('user-1', 2500);
      expect(profiles.profile!.targetWaterMl, 2500);
    });

    test('rejects goals outside the valid range', () async {
      expect(
        () => repository.setGoal('user-1', 100),
        throwsA(isA<AppException>()),
      );
      expect(
        () => repository.setGoal('user-1', 20000),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('loadHistory', () {
    test('daily period returns one bucket per day', () async {
      final DateTime now = DateTime.now();
      await waterLogs.insert(makeLog(amountMl: 250, loggedAt: now));

      final WaterHistory history = await repository.loadHistory(
        'user-1',
        WaterHistoryPeriod.daily,
      );

      expect(history.period, WaterHistoryPeriod.daily);
      expect(history.buckets.length, 14);
      expect(
        history.buckets.where((WaterHistoryBucket b) => b.intakeMl > 0),
        hasLength(1),
      );
    });
  });
}
