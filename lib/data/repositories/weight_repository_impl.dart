import '../../core/errors/app_exception.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/health_calculator.dart';
import '../../domain/entities/bmi_log.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/weight_history.dart';
import '../../domain/entities/weight_log.dart';
import '../../domain/entities/weight_overview.dart';
import '../../domain/entities/weight_statistics.dart';
import '../../domain/repositories/bmi_log_repository.dart';
import '../../domain/repositories/body_measurement_repository.dart';
import '../../domain/repositories/user_fitness_profile_repository.dart';
import '../../domain/repositories/weight_log_repository.dart';
import '../../domain/repositories/weight_repository.dart';

/// SQLite backed implementation of [WeightRepository].
class WeightRepositoryImpl implements WeightRepository {
  WeightRepositoryImpl({
    required this._weightLogRepository,
    required this._bmiLogRepository,
    required this._bodyMeasurementRepository,
    required this._userProfileRepository,
  });

  static const double _maxWeightKg = 500;
  static const double _minGoalKg = 20;
  static const double _maxGoalKg = 400;

  final WeightLogRepository _weightLogRepository;
  final BmiLogRepository _bmiLogRepository;
  final BodyMeasurementRepository _bodyMeasurementRepository;
  final UserFitnessProfileRepository _userProfileRepository;
  @override
  Future<WeightOverview> loadOverview(String userId) async {
    final List<WeightLog> logs = await _weightLogRepository.getByUserId(
      userId,
    )..sort((WeightLog a, WeightLog b) => a.loggedAt.compareTo(b.loggedAt));

    final List<BmiLog> bmiLogs = await _bmiLogRepository.getByUserId(userId)
      ..sort((BmiLog a, BmiLog b) => b.loggedAt.compareTo(a.loggedAt));

    return WeightOverview(
      logs: logs,
      profile: await _userProfileRepository.getById(userId),
      latestBmi: bmiLogs.isEmpty ? null : bmiLogs.first,
      latestMeasurement: await _bodyMeasurementRepository.getLatest(userId),
    );
  }

  @override
  Future<WeightHistory> loadHistory(
    String userId,
    WeightHistoryPeriod period,
  ) async {
    final DateTime now = DateTime.now();
    final List<DateTime> bounds = _periodBounds(period, now);
    final DateTime start = bounds.first;
    final DateTime end = bounds.last;
    final List<WeightLog> logs = await _weightLogRepository.getByDateRange(
      userId,
      start,
      end.add(const Duration(days: 1)),
    );

    return WeightHistory(
      period: period,
      start: start,
      end: end,
      buckets: _bucketize(period, start, logs),
    );
  }

  @override
  Future<WeightStatistics> loadStatistics(String userId) async {
    final List<WeightLog> logs = await _weightLogRepository.getByUserId(
      userId,
    )..sort((WeightLog a, WeightLog b) => a.loggedAt.compareTo(b.loggedAt));

    if (logs.isEmpty) {
      return const WeightStatistics();
    }

    double min = logs.first.weightKg;
    double max = logs.first.weightKg;
    double sum = 0;
    final Set<DateTime> days = <DateTime>{};
    for (final WeightLog log in logs) {
      final double weight = log.weightKg;
      if (weight < min) min = weight;
      if (weight > max) max = weight;
      sum += weight;
      days.add(dayStart(log.loggedAt));
    }

    final List<DateTime> sortedDays = days.toList()..sort();
    final double start = logs.first.weightKg;
    final double current = logs.last.weightKg;

    return WeightStatistics(
      startWeightKg: start,
      currentWeightKg: current,
      minWeightKg: min,
      maxWeightKg: max,
      averageWeightKg: sum / logs.length,
      totalChangeKg: current - start,
      daysTracked: days.length,
      totalEntries: logs.length,
      currentStreak: currentStreak(sortedDays.toSet(), DateTime.now()),
      longestStreak: longestStreak(sortedDays),
      firstDate: logs.first.loggedAt,
      lastDate: logs.last.loggedAt,
    );
  }

  @override
  Future<double?> getGoal(String userId) async {
    final UserProfile? profile = await _userProfileRepository.getById(userId);
    return profile?.targetWeightKg;
  }

  @override
  Future<void> setGoal(String userId, double goalKg) async {
    if (goalKg < _minGoalKg) throw const AppException('errorWeightGoalTooLow');
    if (goalKg > _maxGoalKg) throw const AppException('errorWeightGoalTooHigh');
    final UserProfile? existing = await _userProfileRepository.getById(userId);
    final UserProfile updated = (existing ?? UserProfile(
      userId: userId,
      updatedAt: DateTime.now(),
    )).copyWith(targetWeightKg: goalKg, updatedAt: DateTime.now());
    await _userProfileRepository.upsert(updated);
  }

  @override
  Future<WeightLog> addWeight(
    String userId,
    double weightKg, {
    DateTime? date,
    String? note,
  }) async {
    _validateWeight(weightKg);
    final DateTime when = date ?? DateTime.now();
    final WeightLog log = WeightLog(
      userId: userId,
      weightKg: weightKg,
      loggedAt: when,
      createdAt: DateTime.now(),
      note: cleanNote(note),
    );
    final int id = await _weightLogRepository.insert(log);

    final UserProfile? profile = await _userProfileRepository.getById(userId);
    final double? heightCm = profile?.heightCm;
    if (heightCm != null && heightCm > 0) {
      final double? bmi = HealthCalculator.bmi(
        weightKg: weightKg,
        heightCm: heightCm,
      );
      if (bmi != null) {
        await _bmiLogRepository.insert(
          BmiLog(
            userId: userId,
            bmi: bmi,
            weightKg: weightKg,
            heightCm: heightCm,
            category: HealthCalculator.classify(bmi).name,
            loggedAt: when,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    return log.copyWith(id: id);
  }

  @override
  Future<void> updateWeight(WeightLog log) async {
    _validateWeight(log.weightKg);
    await _weightLogRepository.update(
      log.copyWith(note: cleanNote(log.note)),
    );
  }

  @override
  Future<void> deleteWeight(int id) => _weightLogRepository.delete(id);

  List<DateTime> _periodBounds(WeightHistoryPeriod period, DateTime now) {
    final DateTime today = dayStart(now);
    return switch (period) {
      WeightHistoryPeriod.daily => <DateTime>[
        today.subtract(const Duration(days: 13)),
        today,
      ],
      WeightHistoryPeriod.weekly => <DateTime>[
        weekStart(today).subtract(const Duration(days: 7 * 7)),
        today,
      ],
      WeightHistoryPeriod.monthly => <DateTime>[
        DateTime(now.year, now.month - 11, 1),
        today,
      ],
      WeightHistoryPeriod.yearly => <DateTime>[
        DateTime(now.year - 4, 1, 1),
        today,
      ],
    };
  }

  List<WeightHistoryBucket> _bucketize(
    WeightHistoryPeriod period,
    DateTime start,
    List<WeightLog> logs,
  ) {
    final Map<DateTime, List<WeightLog>> byStart = <DateTime, List<WeightLog>>{};
    for (final WeightLog log in logs) {
      final DateTime bucketStart = _bucketStart(period, log.loggedAt);
      byStart.putIfAbsent(bucketStart, () => <WeightLog>[]).add(log);
    }

    final List<WeightHistoryBucket> buckets = <WeightHistoryBucket>[];
    DateTime cursor = _bucketStart(period, start);
    final DateTime end = _bucketStart(period, DateTime.now());
    while (!cursor.isAfter(end)) {
      final List<WeightLog>? bucketLogs = byStart[cursor];
      if (bucketLogs == null || bucketLogs.isEmpty) {
        buckets.add(
          WeightHistoryBucket(
            start: cursor,
            end: _bucketEnd(period, cursor),
            latestWeightKg: 0,
            firstWeightKg: 0,
            entries: 0,
          ),
        );
      } else {
        bucketLogs.sort(
          (WeightLog a, WeightLog b) => a.loggedAt.compareTo(b.loggedAt),
        );
        buckets.add(
          WeightHistoryBucket(
            start: cursor,
            end: _bucketEnd(period, cursor),
            latestWeightKg: bucketLogs.last.weightKg,
            firstWeightKg: bucketLogs.first.weightKg,
            entries: bucketLogs.length,
          ),
        );
      }
      cursor = _advanceBucket(period, cursor);
    }
    return buckets;
  }

  DateTime _bucketStart(WeightHistoryPeriod period, DateTime date) {
    return switch (period) {
      WeightHistoryPeriod.daily => dayStart(date),
      WeightHistoryPeriod.weekly => weekStart(date),
      WeightHistoryPeriod.monthly => DateTime(date.year, date.month, 1),
      WeightHistoryPeriod.yearly => DateTime(date.year, 1, 1),
    };
  }

  DateTime _bucketEnd(WeightHistoryPeriod period, DateTime start) {
    return _advanceBucket(period, start).subtract(const Duration(days: 1));
  }

  DateTime _advanceBucket(WeightHistoryPeriod period, DateTime cursor) {
    return switch (period) {
      WeightHistoryPeriod.daily => cursor.add(const Duration(days: 1)),
      WeightHistoryPeriod.weekly => cursor.add(const Duration(days: 7)),
      WeightHistoryPeriod.monthly => DateTime(
        cursor.year,
        cursor.month + 1,
        1,
      ),
      WeightHistoryPeriod.yearly => DateTime(cursor.year + 1, 1, 1),
    };
  }

  void _validateWeight(double weightKg) {
    if (weightKg <= 0) throw const AppException('errorWeightNegative');
    if (weightKg > _maxWeightKg) {
      throw const AppException('errorWeightUnrealistic');
    }
  }
}
