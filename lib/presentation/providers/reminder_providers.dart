import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/services/notifications/local_notification_service.dart';
import '../../data/services/notifications/reminder_schedule.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_history.dart';
import '../../domain/entities/reminder_statistics.dart';
import '../../domain/entities/smart_reminder_suggestion.dart';
import '../../injection/dependency_injection.dart';
import '../../presentation/router/app_router.dart';
import 'auth_provider.dart';

/// Global reminder notification settings (device-level, persisted in
/// SharedPreferences) merged with each reminder's own flags at schedule time.
class ReminderSettingsState {
  const ReminderSettingsState({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.silentMode = false,
    this.timeFormat = ReminderTimeFormat.h12,
  });

  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool silentMode;
  final ReminderTimeFormat timeFormat;

  ReminderNotificationOptions get notificationOptions =>
      ReminderNotificationOptions(
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
        silentMode: silentMode,
      );

  ReminderSettingsState copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? silentMode,
    ReminderTimeFormat? timeFormat,
  }) {
    return ReminderSettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      silentMode: silentMode ?? this.silentMode,
      timeFormat: timeFormat ?? this.timeFormat,
    );
  }
}

/// Owns the device-level reminder notification settings.
class ReminderSettingsController extends Notifier<ReminderSettingsState> {
  @override
  ReminderSettingsState build() {
    final prefs = ref.read(appPreferencesRepositoryProvider);
    return ReminderSettingsState(
      soundEnabled: prefs.getNotificationSound(),
      vibrationEnabled: prefs.getVibration(),
      silentMode: prefs.getSilentMode(),
      timeFormat: prefs.getReminderTimeFormat(),
    );
  }

  Future<void> setSoundEnabled(bool value) async {
    state = state.copyWith(soundEnabled: value);
    await ref.read(appPreferencesRepositoryProvider).setNotificationSound(value);
    await rescheduleRemindersInContainer(ref.container);
  }

  Future<void> setVibrationEnabled(bool value) async {
    state = state.copyWith(vibrationEnabled: value);
    await ref.read(appPreferencesRepositoryProvider).setVibration(value);
    await rescheduleRemindersInContainer(ref.container);
  }

  Future<void> setSilentMode(bool value) async {
    state = state.copyWith(silentMode: value);
    await ref.read(appPreferencesRepositoryProvider).setSilentMode(value);
    await rescheduleRemindersInContainer(ref.container);
  }

  Future<void> setTimeFormat(ReminderTimeFormat format) async {
    state = state.copyWith(timeFormat: format);
    await ref
        .read(appPreferencesRepositoryProvider)
        .setReminderTimeFormat(format);
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsController, ReminderSettingsState>(
      ReminderSettingsController.new,
    );

/// All reminders for the signed-in user.
class ReminderListController extends AsyncNotifier<List<Reminder>> {
  @override
  Future<List<Reminder>> build() {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) return Future.value(<Reminder>[]);
    return ref.watch(reminderRepositoryProvider).getByUserId(user.id);
  }

  Future<void> refresh() async {
    state = AsyncValue<List<Reminder>>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }
}

final reminderListControllerProvider =
    AsyncNotifierProvider<ReminderListController, List<Reminder>>(
      ReminderListController.new,
    );

/// Status filter used by the history screen; null means all statuses.
final reminderHistoryFilterProvider =
    StateProvider<ReminderHistoryStatus?>((ref) => null);

/// The user's recorded reminder history (newest first).
class ReminderHistoryController extends AsyncNotifier<List<ReminderHistory>> {
  @override
  Future<List<ReminderHistory>> build() {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) return Future.value(<ReminderHistory>[]);
    return ref.watch(reminderHistoryRepositoryProvider).getByUserId(user.id);
  }

  Future<void> refresh() async {
    state = AsyncValue<List<ReminderHistory>>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }
}

final reminderHistoryControllerProvider =
    AsyncNotifierProvider<ReminderHistoryController, List<ReminderHistory>>(
      ReminderHistoryController.new,
    );

/// Reminder history statistics.
final reminderStatisticsProvider =
    FutureProvider.autoDispose<ReminderStatistics>((ref) async {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) {
        return const ReminderStatistics();
      }
      return ref
          .watch(reminderHistoryRepositoryProvider)
          .getStatistics(user.id);
    });

/// Smart contextual suggestions based on real progress.
final smartReminderSuggestionsProvider =
    FutureProvider.autoDispose<List<SmartReminderSuggestion>>((ref) async {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return const <SmartReminderSuggestion>[];
      return ref.watch(smartReminderRepositoryProvider).getSuggestions(user.id);
    });

/// Reminders scheduled to fire on [date].
List<Reminder> remindersOnDate(List<Reminder> reminders, DateTime date) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  final DateTime next = day.add(const Duration(days: 1));
  return reminders
      .where(
        (Reminder r) => reminderOccurrences(r, day, next).isNotEmpty,
      )
      .toList();
}

/// The next occurrence per reminder inside the next [days] days.
List<({Reminder reminder, DateTime at})> upcomingReminders(
  List<Reminder> reminders,
  DateTime now, {
  int days = 7,
}) {
  final DateTime horizon = now.add(Duration(days: days));
  final List<({Reminder reminder, DateTime at})> result =
      <({Reminder reminder, DateTime at})>[];
  for (final Reminder reminder in reminders) {
    final DateTime? next = nextReminderOccurrence(reminder, now);
    if (next != null && !next.isAfter(horizon)) {
      result.add((reminder: reminder, at: next));
    }
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result;
}

/// Creates a new reminder after validating time + duplicates, schedules its
/// notifications and refreshes every dependent provider.
Future<Reminder> createReminder(WidgetRef ref, Reminder draft) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) {
    throw StateError('Reminders require a signed-in user');
  }
  final Reminder reminder = _normalize(draft, user.id);
  if (reminder.allTimes.isEmpty) {
    throw const AppException('reminderErrorNoTime');
  }
  final Reminder? duplicate = await ref
      .read(reminderRepositoryProvider)
      .findDuplicate(reminder);
  if (duplicate != null) {
    throw const AppException('reminderErrorDuplicate');
  }
  final int id = await ref.read(reminderRepositoryProvider).insert(reminder);
  final Reminder saved = reminder.copyWith(id: id);
  final service = ref.read(localNotificationServiceProvider);
  await service.initialize();
  await service.requestPermission();
  await service.scheduleReminder(
    saved,
    options: ref.read(reminderSettingsProvider).notificationOptions,
  );
  ref.invalidate(reminderListControllerProvider);
  return saved;
}

/// Saves edits to an existing reminder and re-schedules notifications.
Future<void> updateReminder(WidgetRef ref, Reminder reminder) async {
  final Reminder normalized = reminder.copyWith(
    updatedAt: DateTime.now(),
    time: reminder.allTimes.first,
  );
  final Reminder? duplicate = await ref
      .read(reminderRepositoryProvider)
      .findDuplicate(normalized);
  if (duplicate != null) {
    throw const AppException('reminderErrorDuplicate');
  }
  await ref.read(reminderRepositoryProvider).update(normalized);
  final service = ref.read(localNotificationServiceProvider);
  await service.cancelReminder(normalized.id ?? 0);
  if (normalized.isEnabled) {
    await service.scheduleReminder(
      normalized,
      options: ref.read(reminderSettingsProvider).notificationOptions,
    );
  }
  ref.invalidate(reminderListControllerProvider);
}

/// Toggles a reminder on/off and reschedules its notifications.
Future<void> toggleReminder(WidgetRef ref, Reminder reminder, bool enabled) async {
  await updateReminder(ref, reminder.copyWith(isEnabled: enabled));
}

/// Deletes a reminder, cancels its notifications and removes its history.
Future<void> deleteReminder(WidgetRef ref, int id) async {
  await ref.read(reminderRepositoryProvider).delete(id);
  await ref.read(localNotificationServiceProvider).cancelReminder(id);
  await ref.read(reminderHistoryRepositoryProvider).deleteByReminderId(id);
  ref.invalidate(reminderListControllerProvider);
  ref.invalidate(reminderHistoryControllerProvider);
}

/// Duplicates a reminder (new row, same schedule) and schedules it.
Future<void> duplicateReminder(WidgetRef ref, int id) async {
  final int newId = await ref.read(reminderRepositoryProvider).duplicate(id);
  final Reminder? copy = await ref
      .read(reminderRepositoryProvider)
      .getById(newId);
  if (copy != null) {
    final service = ref.read(localNotificationServiceProvider);
    await service.initialize();
    await service.scheduleReminder(
      copy,
      options: ref.read(reminderSettingsProvider).notificationOptions,
    );
  }
  ref.invalidate(reminderListControllerProvider);
}

/// Records a completed/skipped action for the latest occurrence of [reminderId]
/// and refreshes the history + statistics providers.
Future<void> recordReminderAction(
  WidgetRef ref,
  int reminderId,
  ReminderHistoryStatus status,
) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  final Reminder? reminder = await ref
      .read(reminderRepositoryProvider)
      .getById(reminderId);
  if (reminder == null) return;

  final DateTime now = DateTime.now();
  final List<DateTime> occurrences = reminderOccurrences(
    reminder,
    reminder.createdAt,
    now,
  );
  final DateTime scheduledFor = occurrences.isEmpty ? now : occurrences.last;

  final historyRepository = ref.read(reminderHistoryRepositoryProvider);
  final List<DateTime> recorded = await historyRepository.getScheduledFor(
    reminderId,
  );
  final bool alreadyRecorded = recorded.any(
    (DateTime d) =>
        d.year == scheduledFor.year &&
        d.month == scheduledFor.month &&
        d.day == scheduledFor.day &&
        d.hour == scheduledFor.hour &&
        d.minute == scheduledFor.minute,
  );
  if (alreadyRecorded) return;

  await historyRepository.insert(
    ReminderHistory(
      userId: user.id,
      reminderId: reminderId,
      status: status,
      scheduledFor: scheduledFor,
      actedAt: now,
      createdAt: now,
    ),
  );
  ref.invalidate(reminderHistoryControllerProvider);
  ref.invalidate(reminderStatisticsProvider);
}

/// Records missed occurrences since the last sync and refreshes the history.
Future<void> syncMissedReminders(WidgetRef ref) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  final int created = await ref
      .read(reminderHistoryRepositoryProvider)
      .syncMissed(user.id, DateTime.now());
  if (created > 0) {
    ref.invalidate(reminderHistoryControllerProvider);
    ref.invalidate(reminderStatisticsProvider);
  }
}

/// Re-syncs every scheduled notification with the signed-in user's reminders.
/// Called during app bootstrap (handles timezone changes + reboots) and after
/// settings changes.
Future<void> rescheduleReminders(WidgetRef ref) async {
  await rescheduleRemindersInContainer(ProviderScope.containerOf(ref.context));
}

/// Container-based variant so it can be driven from notifiers, the app
/// bootstrap and the notification action handler alike.
Future<void> rescheduleRemindersInContainer(ProviderContainer container) async {
  final AppUser? user = container.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  final service = container.read(localNotificationServiceProvider);
  await service.initialize();
  await service.requestPermission();
  await service.cancelAll();
  final List<Reminder> reminders = await container
      .read(reminderRepositoryProvider)
      .getByUserId(user.id);
  final options = container.read(reminderSettingsProvider).notificationOptions;
  for (final Reminder reminder in reminders) {
    if (!reminder.isEnabled) continue;
    await service.scheduleReminder(reminder, options: options);
  }
}

/// Binds the local notification tap/action callbacks so that tapping a
/// notification opens its related screen and pressing Complete / Skip records
/// history. Call once during app bootstrap (e.g. in the splash screen).
void bindReminderNotificationHandler(WidgetRef ref) {
  final ProviderContainer container = ProviderScope.containerOf(ref.context);
  LocalNotificationService.instance.onNotificationAction = (
    String? actionId,
    int reminderId,
  ) {
    unawaited(_handleNotificationAction(container, actionId, reminderId));
  };
}

Future<void> _handleNotificationAction(
  ProviderContainer container,
  String? actionId,
  int reminderId,
) async {
  if (actionId == NotificationActions.complete ||
      actionId == NotificationActions.skip) {
    final ReminderHistoryStatus status = actionId == NotificationActions.complete
        ? ReminderHistoryStatus.completed
        : ReminderHistoryStatus.skipped;
    final ReminderHistory? history = _actionHistory(
      container,
      reminderId,
      status,
    );
    if (history == null) return;
    await container.read(reminderHistoryRepositoryProvider).insert(history);
    container.invalidate(reminderHistoryControllerProvider);
    container.invalidate(reminderStatisticsProvider);
    return;
  }

  // Plain tap: open the related screen for the reminder.
  final Reminder? reminder = await container
      .read(reminderRepositoryProvider)
      .getById(reminderId);
  final String route = reminder?.relatedScreen ?? AppRoutes.reminders;
  container.read(appRouterProvider).push(route);
}

ReminderHistory? _actionHistory(
  ProviderContainer container,
  int reminderId,
  ReminderHistoryStatus status,
) {
  final AppUser? user = container.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return null;
  final DateTime now = DateTime.now();
  return ReminderHistory(
    userId: user.id,
    reminderId: reminderId,
    status: status,
    scheduledFor: now,
    actedAt: now,
    createdAt: now,
  );
}

/// Normalises a draft reminder (clamps times, fills schedule defaults and the
/// related screen) before persistence.
Reminder _normalize(Reminder draft, String userId) {
  final List<String> times = <String>[];
  for (final String time in draft.allTimes) {
    final (int hour, int minute) = parseHhmm(time);
    if (!times.contains(formatHhmm(hour, minute))) {
      times.add(formatHhmm(hour, minute));
    }
  }
  final String primary = times.isEmpty ? '08:00' : times.first;
  final DateTime now = DateTime.now();
  return Reminder(
    id: draft.id,
    userId: userId,
    title: draft.title.trim(),
    body: draft.body?.trim(),
    reminderType: draft.reminderType,
    time: primary,
    times: times.length > 1 ? times.sublist(1) : const <String>[],
    daysOfWeek: draft.daysOfWeek,
    scheduleType: draft.scheduleType,
    startDate: draft.startDate,
    endDate: draft.endDate,
    monthDay: draft.monthDay,
    icon: draft.icon ?? 'notifications',
    colorValue: draft.colorValue,
    soundEnabled: draft.soundEnabled,
    vibrationEnabled: draft.vibrationEnabled,
    silentMode: draft.silentMode,
    showActionButtons: draft.showActionButtons,
    relatedScreen: draft.relatedScreen ?? _relatedScreenFor(draft.reminderType),
    isEnabled: draft.isEnabled,
    lastTriggeredAt: draft.lastTriggeredAt,
    createdAt: draft.createdAt,
    updatedAt: now,
  );
}

/// Default related screen for each reminder type (kept in sync with
/// [AppRoutes]).
String _relatedScreenFor(ReminderType type) {
  return switch (type) {
    ReminderType.water => AppRoutes.water,
    ReminderType.workout => AppRoutes.workoutList,
    ReminderType.meal => AppRoutes.mealPlanner,
    ReminderType.weight => AppRoutes.weightHistory,
    ReminderType.sleep => AppRoutes.reminders,
    ReminderType.medicine => AppRoutes.reminders,
    ReminderType.step => AppRoutes.reminders,
    ReminderType.custom => AppRoutes.reminders,
  };
}

/// Default display colour (ARGB) for each reminder type.
int defaultColorFor(ReminderType type) {
  return switch (type) {
    ReminderType.water => 0xFF3B82F6,
    ReminderType.workout => 0xFF0E9F6E,
    ReminderType.meal => 0xFFF97316,
    ReminderType.weight => 0xFF6D5BD0,
    ReminderType.sleep => 0xFFA78BFA,
    ReminderType.medicine => 0xFFE5484D,
    ReminderType.step => 0xFF22C55E,
    ReminderType.custom => 0xFF4A5568,
  };
}

/// Whether the module is usable on this platform.
bool get remindersSupported => LocalNotificationService.isSupported;
