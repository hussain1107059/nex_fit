import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/sleep_log.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';
import 'dashboard_providers.dart';

/// All sleep records for the current user, newest night first.
final sleepHistoryProvider = FutureProvider.autoDispose<List<SleepLog>>((ref) async {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return const <SleepLog>[];
  final List<SleepLog> logs = await ref
      .read(sleepLogRepositoryProvider)
      .getByUserId(user.id);
  logs.sort((SleepLog a, SleepLog b) => b.sleepDate.compareTo(a.sleepDate));
  return logs;
});

/// Persists a new sleep record and refreshes the history + dashboard.
Future<void> addSleepEntry(
  WidgetRef ref, {
  required DateTime sleepDate,
  required int durationMinutes,
  int quality = 0,
  String? note,
}) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  await ref.read(sleepLogRepositoryProvider).insert(
    SleepLog(
      userId: user.id,
      sleepDate: sleepDate,
      durationMinutes: durationMinutes,
      quality: quality,
      note: note,
      createdAt: DateTime.now(),
    ),
  );
  _refreshSleepDependents(ref);
}

/// Saves edits to an existing sleep record.
Future<void> updateSleepEntry(WidgetRef ref, SleepLog log) async {
  await ref.read(sleepLogRepositoryProvider).update(log);
  _refreshSleepDependents(ref);
}

/// Deletes a sleep record.
Future<void> deleteSleepEntry(WidgetRef ref, int id) async {
  await ref.read(sleepLogRepositoryProvider).delete(id);
  _refreshSleepDependents(ref);
}

void _refreshSleepDependents(WidgetRef ref) {
  ref.invalidate(sleepHistoryProvider);
  ref.invalidate(dashboardControllerProvider);
}