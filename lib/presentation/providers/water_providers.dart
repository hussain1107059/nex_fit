import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/entities/daily_hydration.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/water_history.dart';
import '../../domain/entities/water_log.dart';
import '../../domain/entities/water_statistics.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';
import 'dashboard_providers.dart';

/// Calendar day currently selected inside the water tracker.
final waterSelectedDateProvider = StateProvider<DateTime>((ref) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Loads and refreshes the daily hydration aggregate for the selected date.
class WaterDailyController extends AsyncNotifier<DailyHydration> {
  @override
  Future<DailyHydration> build() {
    final DateTime date = ref.watch(waterSelectedDateProvider);
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      throw StateError('Water tracker requires a signed-in user');
    }
    return ref.read(hydrationRepositoryProvider).loadDaily(user.id, date);
  }

  Future<void> refresh() async {
    state = AsyncValue<DailyHydration>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }
}

final waterDailyControllerProvider =
    AsyncNotifierProvider<WaterDailyController, DailyHydration>(
      WaterDailyController.new,
    );

/// The user's daily hydration goal (used by charts as a target line).
final waterGoalMlProvider = FutureProvider.autoDispose<int>((ref) async {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return 2000;
  return ref.read(hydrationRepositoryProvider).getGoal(user.id);
});

/// Aggregation window shown by the water history screen.
final waterHistoryPeriodProvider = StateProvider<WaterHistoryPeriod>(
  (ref) => WaterHistoryPeriod.daily,
);

/// Water history for the currently selected period.
final waterHistoryProvider = FutureProvider.autoDispose<WaterHistory>((ref) {
  final WaterHistoryPeriod period = ref.watch(waterHistoryPeriodProvider);
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) {
    throw StateError('Water history requires a signed-in user');
  }
  return ref.read(hydrationRepositoryProvider).loadHistory(user.id, period);
});

/// Lifetime water statistics.
final waterStatisticsProvider =
    FutureProvider.autoDispose<WaterStatistics>((ref) {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) {
        throw StateError('Water statistics requires a signed-in user');
      }
      return ref.read(hydrationRepositoryProvider).loadStatistics(user.id);
    });

/// The user's hydration reminders (only water type is used by this module).
final waterRemindersProvider = FutureProvider.autoDispose<List<Reminder>>((
  ref,
) async {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return const <Reminder>[];
  return ref.read(hydrationRepositoryProvider).getReminders(user.id);
});

/// Logs a water entry for the current user and refreshes every aggregate that
/// depends on the water log (water tracker, statistics and home dashboard).
Future<void> addWaterEntry(
  WidgetRef ref,
  int amountMl, {
  DateTime? date,
  String? note,
}) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  await ref.read(hydrationRepositoryProvider).addEntry(
    user.id,
    amountMl,
    date: date,
    note: note,
  );
  ref.invalidate(waterDailyControllerProvider);
  ref.invalidate(waterStatisticsProvider);
  ref.invalidate(dashboardControllerProvider);
}

/// Edits an existing water entry.
Future<void> updateWaterEntry(WidgetRef ref, WaterLog log) async {
  await ref.read(hydrationRepositoryProvider).updateEntry(log);
  ref.invalidate(waterDailyControllerProvider);
  ref.invalidate(waterStatisticsProvider);
  ref.invalidate(dashboardControllerProvider);
}

/// Deletes a water entry.
Future<void> deleteWaterEntry(WidgetRef ref, int id) async {
  await ref.read(hydrationRepositoryProvider).deleteEntry(id);
  ref.invalidate(waterDailyControllerProvider);
  ref.invalidate(waterStatisticsProvider);
  ref.invalidate(dashboardControllerProvider);
}

/// Persists a new daily hydration goal and refreshes the tracker + dashboard.
Future<void> setWaterGoal(WidgetRef ref, int goalMl) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  await ref.read(hydrationRepositoryProvider).setGoal(user.id, goalMl);
  ref.invalidate(waterDailyControllerProvider);
  ref.invalidate(dashboardControllerProvider);
}

/// Creates a water reminder (and schedules its local notifications).
Future<int> createWaterReminder(
  WidgetRef ref, {
  required String title,
  String? body,
  required String time,
  List<int> daysOfWeek = const <int>[],
}) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) {
    throw StateError('Water reminders require a signed-in user');
  }
  final DateTime now = DateTime.now();
  final int id = await ref.read(hydrationRepositoryProvider).addReminder(
    Reminder(
      userId: user.id,
      title: title,
      body: body,
      reminderType: ReminderType.water,
      time: time,
      daysOfWeek: daysOfWeek,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
  ref.invalidate(waterRemindersProvider);
  return id;
}

/// Toggles a reminder on/off and reschedules its notifications.
Future<void> toggleWaterReminder(WidgetRef ref, Reminder reminder, bool enabled) async {
  await ref.read(hydrationRepositoryProvider).updateReminder(
    reminder.copyWith(isEnabled: enabled, updatedAt: DateTime.now()),
  );
  ref.invalidate(waterRemindersProvider);
}

/// Saves reminder edits and reschedules its notifications.
Future<void> updateWaterReminder(WidgetRef ref, Reminder reminder) async {
  await ref.read(hydrationRepositoryProvider).updateReminder(
    reminder.copyWith(updatedAt: DateTime.now()),
  );
  ref.invalidate(waterRemindersProvider);
}

/// Deletes a reminder and cancels its notifications.
Future<void> deleteWaterReminder(WidgetRef ref, int id) async {
  await ref.read(hydrationRepositoryProvider).deleteReminder(id);
  ref.invalidate(waterRemindersProvider);
}

/// Re-syncs the scheduled notifications with the signed-in user's reminders.
/// Called once during app bootstrap.
Future<void> rescheduleHydrationReminders(WidgetRef ref) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  await ref.read(hydrationRepositoryProvider).rescheduleAll(user.id);
}
