import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/progress/analytics_report.dart';
import '../../domain/entities/progress/fitness_score.dart';
import '../../domain/entities/progress/goal_progress.dart';
import '../../domain/entities/progress/personal_record.dart';
import '../../domain/entities/progress/report_period.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';

/// Selected report window for the Progress module.
final progressPeriodProvider = StateProvider<ReportPeriod>(
  (ref) => ReportPeriod.last30Days,
);

/// Custom date range used when [progressPeriodProvider] is
/// [ReportPeriod.custom]. `end` is inclusive like a date range picker.
final progressCustomRangeProvider = StateProvider<DateTimeRange?>(
  (ref) => null,
);

/// Loads and refreshes the aggregated report for the selected window.
class ProgressReportController extends AsyncNotifier<AnalyticsReport> {
  @override
  Future<AnalyticsReport> build() {
    return _load(
      ref.watch(progressPeriodProvider),
      ref.watch(progressCustomRangeProvider),
    );
  }

  Future<AnalyticsReport> _load(
    ReportPeriod period,
    DateTimeRange? range,
  ) async {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      throw StateError('Progress report requires a signed-in user');
    }
    final DateTime? customStart = range?.start;
    final DateTime? customEnd = range?.end.add(const Duration(days: 1));
    return ref.watch(progressAnalyticsRepositoryProvider).loadReport(
          user.id,
          period,
          customStart: customStart,
          customEnd: customEnd,
        );
  }

  Future<void> refresh() async {
    state = AsyncValue<AnalyticsReport>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => _load(
        ref.read(progressPeriodProvider),
        ref.read(progressCustomRangeProvider),
      ),
    );
  }
}

final progressReportControllerProvider =
    AsyncNotifierProvider<ProgressReportController, AnalyticsReport>(
      ProgressReportController.new,
    );

/// Lifetime personal records.
final personalRecordsProvider =
    FutureProvider.autoDispose<List<PersonalRecord>>((ref) async {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return const <PersonalRecord>[];
      return ref
          .watch(progressAnalyticsRepositoryProvider)
          .loadPersonalRecords(user.id);
    });

/// Live progress towards all tracked goals.
final goalProgressProvider =
    FutureProvider.autoDispose<List<GoalProgress>>((ref) async {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return const <GoalProgress>[];
      return ref
          .watch(progressAnalyticsRepositoryProvider)
          .loadGoalProgress(user.id);
    });

/// Composite fitness score (0..100).
final fitnessScoreProvider =
    FutureProvider.autoDispose<FitnessScore>((ref) async {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) {
        return const FitnessScore(
          score: 0,
          label: 'gettingStarted',
          metrics: <FitnessScoreMetric>[],
        );
      }
      return ref
          .watch(progressAnalyticsRepositoryProvider)
          .loadFitnessScore(user.id);
    });
