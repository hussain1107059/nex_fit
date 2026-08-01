import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/errors/app_exception.dart';
import 'package:nexfit/data/repositories/weight_repository_impl.dart';
import 'package:nexfit/domain/entities/bmi_log.dart';
import 'package:nexfit/domain/entities/body_measurement.dart';
import 'package:nexfit/domain/entities/user_profile.dart';
import 'package:nexfit/domain/entities/weight_history.dart';
import 'package:nexfit/domain/entities/weight_log.dart';
import 'package:nexfit/domain/entities/weight_overview.dart';
import 'package:nexfit/domain/entities/weight_statistics.dart';
import 'package:nexfit/domain/repositories/bmi_log_repository.dart';
import 'package:nexfit/domain/repositories/body_measurement_repository.dart';
import 'package:nexfit/domain/repositories/user_fitness_profile_repository.dart';
import 'package:nexfit/domain/repositories/weight_log_repository.dart';

class _MemoryWeightLogRepository implements WeightLogRepository {
  final List<WeightLog> logs = <WeightLog>[];
  int _nextId = 1;

  @override
  Future<int> insert(WeightLog log) async {
    final WeightLog copy = log.copyWith(id: _nextId++);
    logs.add(copy);
    return copy.id!;
  }

  @override
  Future<void> update(WeightLog log) async {
    final int index = logs.indexWhere((WeightLog l) => l.id == log.id);
    if (index >= 0) logs[index] = log;
  }

  @override
  Future<WeightLog?> getById(int id) async {
    for (final WeightLog log in logs) {
      if (log.id == id) return log;
    }
    return null;
  }

  @override
  Future<List<WeightLog>> getByUserId(String userId) async {
    return logs.where((WeightLog l) => l.userId == userId).toList();
  }

  @override
  Future<List<WeightLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    return logs
        .where(
          (WeightLog l) =>
              l.userId == userId &&
              !l.loggedAt.isBefore(start) &&
              l.loggedAt.isBefore(end),
        )
        .toList();
  }

  @override
  Future<WeightLog?> getLatest(String userId) async {
    final List<WeightLog> userLogs = (await getByUserId(userId)).toList()
      ..sort((WeightLog a, WeightLog b) => b.loggedAt.compareTo(a.loggedAt));
    return userLogs.isEmpty ? null : userLogs.first;
  }

  @override
  Future<void> delete(int id) async {
    logs.removeWhere((WeightLog l) => l.id == id);
  }
}

class _MemoryBmiLogRepository implements BmiLogRepository {
  final List<BmiLog> logs = <BmiLog>[];
  int _nextId = 1;

  @override
  Future<int> insert(BmiLog log) async {
    final BmiLog copy = log.copyWith(id: _nextId++);
    logs.add(copy);
    return copy.id!;
  }

  @override
  Future<BmiLog?> getById(int id) async {
    for (final BmiLog log in logs) {
      if (log.id == id) return log;
    }
    return null;
  }

  @override
  Future<List<BmiLog>> getByUserId(String userId) async {
    return logs.where((BmiLog l) => l.userId == userId).toList();
  }

  @override
  Future<void> delete(int id) async {
    logs.removeWhere((BmiLog l) => l.id == id);
  }
}

class _MemoryBodyMeasurementRepository implements BodyMeasurementRepository {
  final List<BodyMeasurement> items = <BodyMeasurement>[];
  int _nextId = 1;

  @override
  Future<int> insert(BodyMeasurement measurement) async {
    final BodyMeasurement copy = measurement.copyWith(id: _nextId++);
    items.add(copy);
    return copy.id!;
  }

  @override
  Future<void> update(BodyMeasurement measurement) async {
    final int index = items.indexWhere(
      (BodyMeasurement m) => m.id == measurement.id,
    );
    if (index >= 0) items[index] = measurement;
  }

  @override
  Future<BodyMeasurement?> getById(int id) async {
    for (final BodyMeasurement m in items) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  Future<List<BodyMeasurement>> getByUserId(String userId) async {
    return items.where((BodyMeasurement m) => m.userId == userId).toList();
  }

  @override
  Future<List<BodyMeasurement>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    return items
        .where(
          (BodyMeasurement m) =>
              m.userId == userId &&
              !m.measuredAt.isBefore(start) &&
              m.measuredAt.isBefore(end),
        )
        .toList();
  }

  @override
  Future<BodyMeasurement?> getLatest(String userId) async {
    final List<BodyMeasurement> sorted = items
        .where((BodyMeasurement m) => m.userId == userId)
        .toList()
      ..sort((BodyMeasurement a, BodyMeasurement b) =>
          b.measuredAt.compareTo(a.measuredAt));
    return sorted.isEmpty ? null : sorted.first;
  }

  @override
  Future<void> delete(int id) async {
    items.removeWhere((BodyMeasurement m) => m.id == id);
  }
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
  late _MemoryWeightLogRepository weightLogs;
  late _MemoryBmiLogRepository bmiLogs;
  late _MemoryBodyMeasurementRepository measurements;
  late _MemoryUserProfileRepository profiles;
  late WeightRepositoryImpl repository;

  setUp(() {
    weightLogs = _MemoryWeightLogRepository();
    bmiLogs = _MemoryBmiLogRepository();
    measurements = _MemoryBodyMeasurementRepository();
    profiles = _MemoryUserProfileRepository();
    repository = WeightRepositoryImpl(
      weightLogRepository: weightLogs,
      bmiLogRepository: bmiLogs,
      bodyMeasurementRepository: measurements,
      userProfileRepository: profiles,
    );
  });

  WeightLog makeLog({
    int? id,
    double weightKg = 70,
    String? note,
    DateTime? loggedAt,
  }) {
    return WeightLog(
      id: id,
      userId: 'user-1',
      weightKg: weightKg,
      note: note,
      loggedAt: loggedAt ?? DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  group('addWeight', () {
    test('inserts the log with a cleaned note', () async {
      final WeightLog log = await repository.addWeight(
        'user-1',
        72.5,
        note: '  after gym  ',
      );

      expect(log.id, isNotNull);
      expect(weightLogs.logs, hasLength(1));
      expect(weightLogs.logs.single.note, 'after gym');
    });

    test('rejects a negative weight', () async {
      expect(
        () => repository.addWeight('user-1', -1),
        throwsA(isA<AppException>()),
      );
    });

    test('rejects an unrealistic weight', () async {
      expect(
        () => repository.addWeight('user-1', 600),
        throwsA(isA<AppException>()),
      );
    });

    test('writes a BMI log when a height profile exists', () async {
      await profiles.upsert(
        UserProfile(userId: 'user-1', heightCm: 175, updatedAt: DateTime.now()),
      );

      await repository.addWeight('user-1', 70);

      expect(bmiLogs.logs, hasLength(1));
      expect(bmiLogs.logs.single.bmi, closeTo(22.86, 0.01));
    });

    test('skips the BMI log when the profile has no height', () async {
      await repository.addWeight('user-1', 70);
      expect(bmiLogs.logs, isEmpty);
    });
  });

  group('loadStatistics', () {
    test('returns empty statistics for no logs', () async {
      final WeightStatistics stats = await repository.loadStatistics('user-1');
      expect(stats.isEmpty, isTrue);
      expect(stats.totalEntries, 0);
    });

    test('computes min, max, average and change', () async {
      final DateTime day1 = DateTime(2026, 8, 1);
      final DateTime day2 = DateTime(2026, 8, 2);
      await weightLogs.insert(makeLog(weightKg: 80, loggedAt: day1));
      await weightLogs.insert(makeLog(weightKg: 76, loggedAt: day2));

      final WeightStatistics stats = await repository.loadStatistics('user-1');

      expect(stats.startWeightKg, 80);
      expect(stats.currentWeightKg, 76);
      expect(stats.minWeightKg, 76);
      expect(stats.maxWeightKg, 80);
      expect(stats.averageWeightKg, 78);
      expect(stats.totalChangeKg, -4);
      expect(stats.totalEntries, 2);
    });
  });

  group('loadHistory', () {
    test('daily period returns one bucket per day', () async {
      final DateTime now = DateTime.now();
      await weightLogs.insert(makeLog(weightKg: 70, loggedAt: now));

      final WeightHistory history = await repository.loadHistory(
        'user-1',
        WeightHistoryPeriod.daily,
      );

      expect(history.period, WeightHistoryPeriod.daily);
      expect(history.buckets.length, 14);
      expect(history.loggedBuckets, 1);
      expect(history.latestWeight, 70);
    });
  });

  group('setGoal', () {
    test('upserts the target weight on the profile', () async {
      await repository.setGoal('user-1', 68);

      expect(profiles.profile, isNotNull);
      expect(profiles.profile!.targetWeightKg, 68);
    });

    test('rejects goals outside the valid range', () async {
      expect(
        () => repository.setGoal('user-1', 10),
        throwsA(isA<AppException>()),
      );
      expect(
        () => repository.setGoal('user-1', 500),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('loadOverview', () {
    test('assembles overview from all sources', () async {
      await profiles.upsert(
        UserProfile(userId: 'user-1', heightCm: 175, updatedAt: DateTime.now()),
      );
      await repository.addWeight('user-1', 70);

      final WeightOverview overview = await repository.loadOverview('user-1');

      expect(overview.logs, hasLength(1));
      expect(overview.latestBmi, isNotNull);
      expect(overview.latestBmi!.bmi, closeTo(22.86, 0.01));
    });
  });
}
