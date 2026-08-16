import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/reminder_history_local_data_source.dart';
import 'package:nexfit/data/datasources/local/reminder_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/repositories/reminder_history_repository_impl.dart';
import 'package:nexfit/data/repositories/reminder_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/services/notifications/reminder_schedule.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_contracts.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/domain/entities/app_user.dart';
import 'package:nexfit/domain/entities/common_enums.dart';
import 'package:nexfit/domain/entities/reminder.dart';
import 'package:nexfit/domain/entities/reminder_history.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/repositories/reminder_history_repository.dart';
import 'package:nexfit/domain/repositories/reminder_repository.dart';
import 'package:nexfit/injection/dependency_injection.dart';
import 'package:nexfit/presentation/providers/auth_provider.dart';
import 'package:nexfit/presentation/providers/reminder_providers.dart';

/// PROMPT 34 — Reminders & notifications finalization.
///
/// The reminder module is fully sync-aware: reminder configuration is
/// user-owned and travels through the existing outbox engine (uuid, row
/// version, soft delete) while notification execution stays device-local —
/// the `reminder` table stores no platform notification ids, so pulling a
/// reminder from the cloud can never collide with already-scheduled
/// notifications (deterministic ids derived from the local row id, and a
/// cancel-all + re-schedule pass after every pull). Scheduling maths work in
/// device-local wall-clock time so a device timezone change shifts when a
/// reminder fires without corrupting the stored config.
///
/// See `docs/NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §30.
class _Harness {
  _Harness(this.db);

  final AppDatabase db;

  late final ReminderRepository reminders;
  late final ReminderHistoryRepository history;

  Future<void> init() async {
    final raw = await db.database;
    await raw.insert('users', <String, Object?>{
      'id': 'u-1',
      'name': 'Rahim',
      'email': 'rahim@example.com',
      'provider': 'email',
    });
    await raw.insert('users', <String, Object?>{
      'id': 'u-2',
      'name': 'Karim',
      'email': 'karim@example.com',
      'provider': 'email',
    });

    reminders = ReminderRepositoryImpl(ReminderLocalDataSource(database: db));
    history = ReminderHistoryRepositoryImpl(
      dataSource: ReminderHistoryLocalDataSource(database: db),
      reminderRepository: reminders,
    );
  }

  /// Fresh repositories over the same database (an app restart).
  Future<void> reopen() async {
    reminders = ReminderRepositoryImpl(ReminderLocalDataSource(database: db));
    history = ReminderHistoryRepositoryImpl(
      dataSource: ReminderHistoryLocalDataSource(database: db),
      reminderRepository: reminders,
    );
  }

  Future<void> close() => db.close();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late _Harness harness;

  setUp(() async {
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/reminder_finalization.db',
    );
    harness = _Harness(
      AppDatabase(databaseName: 'reminder_finalization.db'),
    );
    await harness.init();
    SyncEventRecorder.configure(
      repository: SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: harness.db),
      ),
      deviceIdProvider: () async => 'device-1',
    );
  });

  tearDown(() async {
    SyncEventRecorder.setEnabled(false);
    await harness.close();
  });

  const AppUser signedIn = AppUser(
    id: 'u-1',
    email: 'rahim@example.com',
    isEmailVerified: true,
    provider: AuthProvider.email,
  );

  DateTime at(int hour, int minute) => DateTime(2026, 6, 1, hour, minute);

  Reminder dailyReminder({
    String userId = 'u-1',
    String title = 'Drink water',
    String time = '07:00',
    bool isEnabled = true,
  }) {
    return Reminder(
      userId: userId,
      title: title,
      body: 'Stay hydrated',
      reminderType: ReminderType.water,
      time: time,
      daysOfWeek: const <int>[],
      scheduleType: ReminderScheduleType.daily,
      startDate: DateTime(2026, 5, 1),
      icon: 'water_drop',
      colorValue: 0xFF3B82F6,
      relatedScreen: '/water',
      isEnabled: isEnabled,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );
  }

  Future<List<Map<String, Object?>>> eventsFor(String entity) async {
    final raw = await harness.db.database;
    return raw.query(
      'sync_event',
      where: 'entity = ?',
      whereArgs: <Object?>[entity],
      orderBy: 'id ASC',
    );
  }

  Future<void> applyRemote(
    String cloudTable,
    String uuid, {
    Map<String, Object?>? payload,
  }) async {
    final RemoteChangeApplier applier = RemoteChangeApplier(database: harness.db);
    final raw = await harness.db.database;
    await raw.transaction((txn) async {
      await applier.apply(
        txn,
        SyncChange(
          cursorId: 1,
          cloudTable: cloudTable,
          recordId: uuid,
          operation: SyncOperation.create,
          payload: payload ??
              <String, Object?>{
                'id': uuid,
                'user_id': 'u-1',
                'title': 'Morning water',
                'body': 'Drink up',
                'reminder_type': 'water',
                'time': '08:30',
                'days_of_week': '1,2,3',
                'schedule_type': 'weekly',
                'times': '["08:30","20:00"]',
                'start_date': '2026-02-01',
                'end_date': '2026-02-28',
                'month_day': null,
                'icon': 'water_drop',
                'color_value': 4280391411,
                'sound_enabled': false,
                'vibration_enabled': true,
                'silent_mode': true,
                'show_action_buttons': false,
                'related_screen': '/water',
                'is_enabled': true,
                'last_triggered_at': '2026-02-02T08:30:00Z',
                'created_at': '2026-02-01T08:00:00Z',
                'updated_at': '2026-02-01T08:00:00Z',
                'deleted_at': null,
                'row_version': 1,
              },
        ),
      );
    });
  }

  ProviderContainer rescheduleContainer({
    required ReminderRepository repository,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        currentUserProvider.overrideWithValue(signedIn),
        reminderRepositoryProvider.overrideWithValue(repository),
        reminderSettingsProvider.overrideWith(
          () => _FixedReminderSettings(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('PROMPT 34 reminders: create / edit / delete', () {
    test('creating a reminder persists it and records a CREATE event', () async {
      final int id = await harness.reminders.insert(dailyReminder());

      final Reminder? loaded = await harness.reminders.getById(id);
      expect(loaded, isNotNull);
      expect(loaded!.title, 'Drink water');
      expect(loaded.reminderType, ReminderType.water);
      expect(loaded.scheduleType, ReminderScheduleType.daily);
      expect(loaded.allTimes, <String>['07:00']);

      final List<Map<String, Object?>> events = await eventsFor('reminder');
      expect(events, hasLength(1));
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
      expect(events.single['user_id'], 'u-1');
    });

    test('an identical reminder is rejected as a duplicate', () async {
      await harness.reminders.insert(dailyReminder());

      final Reminder? duplicate = await harness.reminders.findDuplicate(
        dailyReminder(title: 'drink water'),
      );
      expect(duplicate, isNotNull, reason: 'matching title/times/type');
      expect(
        await harness.reminders.findDuplicate(
          dailyReminder(title: 'Different', time: '09:00'),
        ),
        isNull,
      );
    });

    test('updating bumps row version and records an UPDATE event', () async {
      final int id = await harness.reminders.insert(dailyReminder());
      await harness.reminders.update(
        dailyReminder().copyWith(id: id, title: 'Drink more', isEnabled: false),
      );

      final Reminder? loaded = await harness.reminders.getById(id);
      expect(loaded!.title, 'Drink more');
      expect(loaded.isEnabled, isFalse);

      final List<Map<String, Object?>> events = await eventsFor('reminder');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('deleting soft-deletes and records a DELETE event', () async {
      final int id = await harness.reminders.insert(dailyReminder());
      await harness.history.insert(
        ReminderHistory(
          userId: 'u-1',
          reminderId: id,
          status: ReminderHistoryStatus.completed,
          scheduledFor: DateTime.utc(2026, 5, 1, 7),
          actedAt: DateTime.utc(2026, 5, 1, 7, 5),
          createdAt: DateTime.utc(2026, 5, 1, 7, 5),
        ),
      );

      await harness.reminders.delete(id);

      expect(await harness.reminders.getById(id), isNull);
      final raw = await harness.db.database;
      final List<Map<String, Object?>> rows = await raw.query(
        'reminder',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      expect(rows.single['deleted_at'], isNotNull);
      final List<Map<String, Object?>> events = await eventsFor('reminder');
      expect(events.last['operation'], SyncOperation.delete.name);
    });
  });

  group('PROMPT 34 reminders: offline', () {
    test('create/edit/delete work locally while offline', () async {
      SyncEventRecorder.setEnabled(false);

      final int id = await harness.reminders.insert(dailyReminder());
      await harness.reminders.update(
        dailyReminder().copyWith(id: id, title: 'Offline edit'),
      );
      final Reminder? edited = await harness.reminders.getById(id);
      expect(edited!.title, 'Offline edit');
      expect(await eventsFor('reminder'), isEmpty,
          reason: 'no outbox events while offline');

      await harness.reminders.delete(id);
      expect(await harness.reminders.getById(id), isNull);

      SyncEventRecorder.setEnabled(true);
      // The queue is drained by the next sync run, not by local edits.
      expect(await eventsFor('reminder'), isEmpty);
    });

    test('the scheduler can read reminders that were created offline', () async {
      SyncEventRecorder.setEnabled(false);
      final int id = await harness.reminders.insert(dailyReminder());
      SyncEventRecorder.setEnabled(true);

      final ProviderContainer container = rescheduleContainer(
        repository: harness.reminders,
      );
      // Device-local pass: cancel all then schedule each enabled reminder.
      await rescheduleRemindersInContainer(container);

      final List<Reminder> enabled = await harness.reminders.getEnabled('u-1');
      expect(enabled.map((Reminder r) => r.id), contains(id));
    });
  });

  group('PROMPT 34 reminders: sync', () {
    test('a remote pull converges without an echo event', () async {
      await applyRemote('reminders', 'rem-uuid-1');

      final List<Reminder> mine = await harness.reminders.getByUserId('u-1');
      expect(mine, hasLength(1));
      final Reminder pulled = mine.single;
      expect(pulled.reminderType, ReminderType.water);
      expect(pulled.allTimes, <String>['08:30', '20:00']);
      expect(pulled.soundEnabled, isFalse);
      expect(pulled.silentMode, isTrue);
      expect(await eventsFor('reminder'), isEmpty,
          reason: 'a pull must never write an outbound event');
    });

    test('re-applying the same remote reminder never duplicates the row',
        () async {
      await applyRemote('reminders', 'rem-uuid-1');
      await applyRemote('reminders', 'rem-uuid-1');

      final List<Reminder> mine = await harness.reminders.getByUserId('u-1');
      expect(mine, hasLength(1), reason: 'idempotent remote apply');
    });

    test('pulls are scoped per user', () async {
      await applyRemote('reminders', 'rem-uuid-1');
      await applyRemote(
        'reminders',
        'rem-uuid-2',
        payload: <String, Object?>{
          'id': 'rem-uuid-2',
          'user_id': 'u-2',
          'title': "Karim's walk",
          'body': null,
          'reminder_type': 'custom',
          'time': '06:15',
          'days_of_week': '',
          'schedule_type': 'daily',
          'times': '[]',
          'start_date': null,
          'end_date': null,
          'month_day': null,
          'icon': 'directions_walk',
          'color_value': null,
          'sound_enabled': true,
          'vibration_enabled': true,
          'silent_mode': false,
          'show_action_buttons': true,
          'related_screen': '/reminders',
          'is_enabled': true,
          'last_triggered_at': null,
          'created_at': '2026-02-01T08:00:00Z',
          'updated_at': '2026-02-01T08:00:00Z',
          'deleted_at': null,
          'row_version': 1,
        },
      );

      final List<Reminder> mine = await harness.reminders.getByUserId('u-1');
      final List<Reminder> theirs = await harness.reminders.getByUserId('u-2');
      expect(mine, hasLength(1));
      expect(theirs, hasLength(1));
      expect(mine.single.title, 'Morning water');
      expect(theirs.single.title, "Karim's walk");
    });

    test('cloud history rows converge without an echo event', () async {
      final int id = await harness.reminders.insert(dailyReminder());
      final raw = await harness.db.database;
      final List<Map<String, Object?>> reminderRow = await raw.query(
        'reminder',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      final String reminderUuid = reminderRow.single['uuid'] as String;

      final RemoteChangeApplier applier = RemoteChangeApplier(database: harness.db);
      await raw.transaction((txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'reminder_history',
            recordId: 'rem-hist-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'rem-hist-uuid-1',
              'user_id': 'u-1',
              'reminder_id': reminderUuid,
              'status': 'completed',
              'scheduled_for': '2026-05-01T07:00:00Z',
              'acted_at': '2026-05-01T07:05:00Z',
              'created_at': '2026-05-01T07:05:00Z',
              'deleted_at': null,
              'row_version': 1,
            },
          ),
        );
      });

      final List<ReminderHistory> mine = await harness.history.getByUserId('u-1');
      expect(mine, hasLength(1));
      expect(mine.single.status, ReminderHistoryStatus.completed);
      expect(mine.single.reminderId, id);
      expect(await eventsFor('reminder_history'), isEmpty);
    });

    test('syncMissed records unattended occurrences', () async {
      final Reminder reminder = dailyReminder().copyWith(
        startDate: DateTime(2026, 5, 31),
        createdAt: DateTime(2026, 5, 31),
        lastTriggeredAt: DateTime(2026, 6, 1, 6),
      );
      final int id = await harness.reminders.insert(reminder);

      final int created = await harness.history.syncMissed('u-1', at(8, 0));

      expect(created, 1, reason: 'only the 07:00 occurrence on June 1');
      final List<ReminderHistory> mine = await harness.history.getByUserId('u-1');
      expect(mine.single.reminderId, id);
      expect(mine.single.status, ReminderHistoryStatus.missed);

      // Running again never records the same occurrence twice.
      final int again = await harness.history.syncMissed('u-1', at(9, 0));
      expect(again, 0);
    });
  });

  group('PROMPT 34 reminders: app restart & timezone', () {
    test('reminders survive a restart and are re-read for scheduling', () async {
      final int id = await harness.reminders.insert(dailyReminder());

      // "Restart": fresh repositories over the same database file.
      final _Harness restarted = _Harness(harness.db);
      await restarted.reopen();
      final Reminder? loaded = await restarted.reminders.getById(id);
      expect(loaded, isNotNull);
      expect(loaded!.title, 'Drink water');
      expect(loaded.isEnabled, isTrue);
      expect(loaded.allTimes, <String>['07:00']);

      // The bootstrap pass re-schedules from local rows without new events.
      final List<Map<String, Object?>> before = await eventsFor('reminder');
      final ProviderContainer container = rescheduleContainer(
        repository: restarted.reminders,
      );
      await rescheduleRemindersInContainer(container);
      expect(await eventsFor('reminder'), before);
    });

    test('occurrences are computed in device-local wall-clock time', () async {
      final Reminder reminder = dailyReminder().copyWith(
        // The config is stored in UTC but the fire time is wall-clock local.
        createdAt: DateTime.utc(2026, 5, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
      );

      final DateTime from = at(0, 0);
      final DateTime to = at(23, 59);
      final List<DateTime> occurrences = reminderOccurrences(reminder, from, to);
      expect(occurrences, isNotEmpty);
      expect(
        occurrences.first.hour,
        7,
        reason: '07:00 fires at 07:00 device-local, never shifted',
      );
      expect(occurrences.first.minute, 0);
    });

    test('a weekly reminder respects its selected weekdays', () async {
      final Reminder weekly = dailyReminder().copyWith(
        scheduleType: ReminderScheduleType.weekly,
        daysOfWeek: const <int>[1, 3, 5],
        time: '18:00',
      );
      final DateTime from = DateTime(2026, 6, 1); // Monday
      final List<DateTime> occurrences =
          reminderOccurrences(weekly, from, from.add(const Duration(days: 6)));
      final Set<int> weekdays = occurrences.map((DateTime d) => d.weekday).toSet();
      expect(weekdays, <int>{1, 3, 5});
      expect(occurrences.every((DateTime d) => d.hour == 18), isTrue);
    });

    test('an end date bounds the occurrence stream', () async {
      final Reminder bounded = dailyReminder().copyWith(
        endDate: DateTime(2026, 6, 3),
      );
      final DateTime from = DateTime(2026, 6, 1);
      final List<DateTime> occurrences = reminderOccurrences(
        bounded,
        from,
        from.add(const Duration(days: 10)),
      );
      expect(occurrences, hasLength(3),
          reason: 'June 1, 2 and 3 only; nothing past the end date');
      expect(occurrences.last.day, 3);
    });

    test('disabled reminders never fire and never schedule', () async {
      final Reminder disabled = dailyReminder(isEnabled: false);
      expect(
        reminderOccurrences(disabled, at(0, 0), at(23, 59)),
        isEmpty,
      );
      expect(nextReminderOccurrence(disabled, at(0, 0)), isNull);
    });

    test('nextReminderOccurrence picks the first future local occurrence',
        () async {
      final Reminder reminder = dailyReminder(time: '07:00');
      final DateTime? next = nextReminderOccurrence(reminder, at(6, 0));
      expect(next, isNotNull);
      expect(next!.hour, 7);
    });
  });
}

class _FixedReminderSettings extends ReminderSettingsController {
  @override
  ReminderSettingsState build() => const ReminderSettingsState();
}