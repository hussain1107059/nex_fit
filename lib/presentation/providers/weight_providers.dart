import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/body_measurement.dart';
import '../../domain/entities/weight_history.dart';
import '../../domain/entities/weight_log.dart';
import '../../domain/entities/weight_overview.dart';
import '../../domain/entities/weight_statistics.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';
import 'dashboard_providers.dart';
import 'profile_providers.dart';

/// Loads and refreshes the weight tracker aggregate.
class WeightOverviewController extends AsyncNotifier<WeightOverview> {
  @override
  Future<WeightOverview> build() {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      throw StateError('Weight tracker requires a signed-in user');
    }
    return ref.read(weightRepositoryProvider).loadOverview(user.id);
  }

  Future<void> refresh() async {
    state = AsyncValue<WeightOverview>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }
}

final weightOverviewControllerProvider =
    AsyncNotifierProvider<WeightOverviewController, WeightOverview>(
      WeightOverviewController.new,
    );

/// Aggregation window shown by the weight trend chart and history screen.
final weightHistoryPeriodProvider = StateProvider<WeightHistoryPeriod>(
  (ref) => WeightHistoryPeriod.daily,
);

/// Weight history for the currently selected period.
final weightHistoryProvider = FutureProvider.autoDispose<WeightHistory>((ref) {
  final WeightHistoryPeriod period = ref.watch(weightHistoryPeriodProvider);
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) {
    throw StateError('Weight history requires a signed-in user');
  }
  return ref.read(weightRepositoryProvider).loadHistory(user.id, period);
});

/// Lifetime weight statistics.
final weightStatisticsProvider =
    FutureProvider.autoDispose<WeightStatistics>((ref) {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) {
        throw StateError('Weight statistics requires a signed-in user');
      }
      return ref.read(weightRepositoryProvider).loadStatistics(user.id);
    });

/// The user's target weight in kg.
final weightGoalProvider = FutureProvider.autoDispose<double?>((ref) async {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return null;
  return ref.read(weightRepositoryProvider).getGoal(user.id);
});

// ---------------------------------------------------------------------------
// Body measurements
// ---------------------------------------------------------------------------

/// All body measurements for the user, newest first.
final bodyMeasurementsProvider =
    FutureProvider.autoDispose<List<BodyMeasurement>>((ref) async {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return const <BodyMeasurement>[];
      return ref.read(bodyMeasurementRepositoryProvider).getByUserId(user.id);
    });

/// Body part highlighted in the measurement trend chart.
final selectedMeasurementProvider = StateProvider<MeasurementType>(
  (ref) => MeasurementType.waist,
);

// ---------------------------------------------------------------------------
// Mutations
// ---------------------------------------------------------------------------

/// Logs a weight entry and refreshes every dependent aggregate.
Future<void> addWeightEntry(
  WidgetRef ref,
  double weightKg, {
  DateTime? date,
  String? note,
}) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  await ref.read(weightRepositoryProvider).addWeight(
    user.id,
    weightKg,
    date: date,
    note: note,
  );
  _refreshWeightDependents(ref);
}

/// Edits an existing weight entry.
Future<void> updateWeightEntry(WidgetRef ref, WeightLog log) async {
  await ref.read(weightRepositoryProvider).updateWeight(log);
  _refreshWeightDependents(ref);
}

/// Deletes a weight entry.
Future<void> deleteWeightEntry(WidgetRef ref, int id) async {
  await ref.read(weightRepositoryProvider).deleteWeight(id);
  _refreshWeightDependents(ref);
}

/// Persists a new target weight.
Future<void> setWeightGoal(WidgetRef ref, double goalKg) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  await ref.read(weightRepositoryProvider).setGoal(user.id, goalKg);
  ref.invalidate(weightOverviewControllerProvider);
  ref.invalidate(weightGoalProvider);
  ref.invalidate(dashboardControllerProvider);
  ref.invalidate(profileControllerProvider);
}

/// Adds a body measurement record.
Future<void> addBodyMeasurement(
  WidgetRef ref,
  BodyMeasurement measurement,
) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  await ref.read(bodyMeasurementRepositoryProvider).insert(measurement);
  ref.invalidate(bodyMeasurementsProvider);
  ref.invalidate(weightOverviewControllerProvider);
  ref.invalidate(dashboardControllerProvider);
}

/// Updates a body measurement record.
Future<void> updateBodyMeasurement(
  WidgetRef ref,
  BodyMeasurement measurement,
) async {
  await ref.read(bodyMeasurementRepositoryProvider).update(measurement);
  ref.invalidate(bodyMeasurementsProvider);
  ref.invalidate(weightOverviewControllerProvider);
  ref.invalidate(dashboardControllerProvider);
}

/// Deletes a body measurement record.
Future<void> deleteBodyMeasurement(WidgetRef ref, int id) async {
  await ref.read(bodyMeasurementRepositoryProvider).delete(id);
  ref.invalidate(bodyMeasurementsProvider);
  ref.invalidate(weightOverviewControllerProvider);
  ref.invalidate(dashboardControllerProvider);
}

void _refreshWeightDependents(WidgetRef ref) {
  ref.invalidate(weightOverviewControllerProvider);
  ref.invalidate(weightHistoryProvider);
  ref.invalidate(weightStatisticsProvider);
  ref.invalidate(weightGoalProvider);
  ref.invalidate(dashboardControllerProvider);
  ref.invalidate(profileControllerProvider);
}
