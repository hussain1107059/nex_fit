import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/domain/entities/app_user.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_conflict_record.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/sync_state.dart';
import 'package:nexfit/domain/repositories/sync_conflict_repository.dart';
import 'package:nexfit/domain/repositories/sync_event_repository.dart';
import 'package:nexfit/domain/repositories/sync_state_repository.dart';
import 'package:nexfit/injection/dependency_injection.dart';
import 'package:nexfit/l10n/app_localizations.dart';
import 'package:nexfit/presentation/providers/auth_provider.dart';
import 'package:nexfit/presentation/providers/settings_providers.dart';
import 'package:nexfit/presentation/providers/sync_providers.dart';
import 'package:nexfit/presentation/widgets/sync/sync_status_chip.dart';

/// PROMPT 22 — Sync Status UX tests.
///
/// Covers the status chip mapping (✓ Synced / ↻ Syncing… / Offline / Sync
/// failed / Conflict needs attention / Pending changes / Not synced yet), the
/// derived status for every engine state, the "Sync now" concurrency guard,
/// the offline completion path and the guarantee that no technical error text
/// ever reaches the UI.

class _FixedSyncController extends SyncController {
  _FixedSyncController(this.ui);

  final SyncUiState ui;

  @override
  SyncUiState build() => ui;
}

class _NoopEventRepo implements SyncEventRepository {
  @override
  Future<int> insert(SyncEvent event) async => 1;
  @override
  Future<void> insertInTransaction(Object txn, SyncEvent event) async {}
  @override
  Future<void> update(SyncEvent event) async {}
  @override
  Future<void> updateAll(List<SyncEvent> events) async {}
  @override
  Future<List<SyncEvent>> getPendingByUserId(
    String userId, {
    int? limit,
    int? offset,
  }) async =>
      <SyncEvent>[];
  @override
  Future<List<SyncEvent>> getNonCompletedByUserId(
    String userId, {
    int limit = 100,
  }) async =>
      <SyncEvent>[];
  @override
  Future<void> requeueAllByUserId(String userId, {required DateTime at}) async {}
  @override
  Future<List<SyncEvent>> getRetryableByUserId(
    String userId, {
    int? limit,
    int? offset,
    DateTime? now,
  }) async =>
      <SyncEvent>[];
  @override
  Future<SyncEvent?> findDuplicate(
    String userId,
    String entity,
    String entityId,
    SyncOperation operation,
  ) async =>
      null;
  @override
  Future<Map<String, int>> countByStatus(String userId) async =>
      <String, int>{};
  @override
  Future<DateTime?> latestSyncedAt(String userId) async => null;
  @override
  Future<void> deleteCompletedOlderThan(
    String userId,
    DateTime threshold,
  ) async {}
  @override
  Future<void> deleteCompletedOlderThanAll(DateTime threshold) async {}
  @override
  Future<void> markProcessing(int id, {required DateTime at}) async {}
  @override
  Future<void> markSuccess(
    int id, {
    required DateTime at,
    required DateTime syncedAt,
  }) async {}
  @override
  Future<void> markRetryableFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
    required DateTime nextRetryAt,
  }) async {}
  @override
  Future<void> markPermanentFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
  }) async {}
  @override
  Future<List<int>> resetStuckProcessingEvents(
    String userId, {
    required DateTime olderThan,
    required DateTime at,
  }) async =>
      <int>[];
  @override
  Future<int> getPendingCount(String userId) async => 0;
  @override
  Future<int> getFailedCount(String userId) async => 0;
}

class _FakeSyncEngine extends SyncEngine {
  _FakeSyncEngine() : super(repository: _NoopEventRepo());

  int processQueueCalls = 0;
  int syncCalls = 0;
  SyncRunResult? processQueueResult;

  @override
  Future<SyncRunResult> processQueue(
    String userId, {
    SyncTransport? transport,
  }) async {
    processQueueCalls++;
    return processQueueResult ?? const SyncRunResult();
  }

  @override
  Future<SyncRunResult> sync({
    required String userId,
    required SyncTransport transport,
    required RemoteChangeApplier applier,
  }) async {
    syncCalls++;
    return const SyncRunResult(hasPulled: true);
  }

  @override
  Future<int> resetStuckProcessingEvents(
    String userId, {
    DateTime? now,
  }) async =>
      0;

  @override
  Future<SyncQueueSnapshot> snapshot(String userId) async {
    // Keep the snapshot consistent with the last run so the status derivation
    // sees the same world as the run that just completed.
    final SyncRunResult? last = processQueueResult;
    if (last != null && last.failed > 0) {
      return SyncQueueSnapshot(
        pending: 0,
        completed: 1,
        failed: last.failed,
        lastSyncedAt: DateTime.now(),
      );
    }
    return const SyncQueueSnapshot(pending: 0, completed: 1, failed: 0);
  }
}

class _CompletedStateRepo implements SyncStateRepository {
  @override
  Future<SyncState?> getByUserId(String userId) async => SyncState(
    userId: userId,
    cursor: 5,
    initialSyncCompleted: true,
    lastSyncAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  @override
  Future<void> upsert(SyncState state) async {}
  @override
  Future<void> upsertInTransaction(
    Object txn,
    SyncState state,
  ) async {}
}

class _CountingStateRepo implements SyncStateRepository {
  int calls = 0;
  @override
  Future<SyncState?> getByUserId(String userId) async {
    calls++;
    return null;
  }
  @override
  Future<void> upsert(SyncState state) async {}
  @override
  Future<void> upsertInTransaction(
    Object txn,
    SyncState state,
  ) async {}
}

class _FakeConflictRepo implements SyncConflictRepository {
  @override
  Future<void> record(SyncConflictRecord record) async {}
  @override
  Future<List<SyncConflictRecord>> getPending(String userId) async =>
      <SyncConflictRecord>[];
  @override
  Future<List<SyncConflictRecord>> getHistory(
    String userId, {
    int limit = 50,
  }) async =>
      <SyncConflictRecord>[];
  @override
  Future<int> countPending(String userId) async => 0;
  @override
  Future<void> markResolved(int id, {required DateTime at}) async {}
}

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SyncStatusKind mapping', () {
    test('every engine status maps to a display kind', () {
      expect(
        syncStatusKindOf(SyncUiStatus.success),
        SyncStatusKind.synced,
      );
      expect(
        syncStatusKindOf(SyncUiStatus.syncing),
        SyncStatusKind.syncing,
      );
      expect(
        syncStatusKindOf(SyncUiStatus.offline),
        SyncStatusKind.offline,
      );
      expect(
        syncStatusKindOf(SyncUiStatus.error),
        SyncStatusKind.failed,
      );
      expect(
        syncStatusKindOf(SyncUiStatus.conflict),
        SyncStatusKind.conflict,
      );
      expect(
        syncStatusKindOf(SyncUiStatus.partialFailure),
        SyncStatusKind.pendingChanges,
      );
      expect(
        syncStatusKindOf(SyncUiStatus.idle),
        SyncStatusKind.idle,
      );
    });
  });

  group('SyncStatusController derivation', () {
    ProviderContainer containerWith(SyncUiState ui, {bool signedIn = true}) {
      return ProviderContainer(
        overrides: <Override>[
          currentUserProvider.overrideWith(
            (ref) => signedIn
                ? const AppUser(id: 'user-1', displayName: 'Tester')
                : AppUser.signedOut,
          ),
          syncControllerProvider.overrideWith(() => _FixedSyncController(ui)),
        ],
      );
    }

    test('signed-out user shows offline', () {
      final ProviderContainer container = containerWith(
        const SyncUiState(),
        signedIn: false,
      );
      addTearDown(container.dispose);
      expect(
        container.read(syncStatusProvider).status,
        SyncUiStatus.offline,
      );
    });

    test('a running sync shows syncing', () {
      final ProviderContainer container = containerWith(
        const SyncUiState(activity: SyncActivity.syncing),
      );
      addTearDown(container.dispose);
      expect(
        container.read(syncStatusProvider).status,
        SyncUiStatus.syncing,
      );
    });

    test('a clean queue with a last sync time shows success', () {
      final ProviderContainer container = containerWith(
        SyncUiState(
          snapshot: SyncQueueSnapshot(
            lastSyncedAt: DateTime(2026, 1, 1),
          ),
        ),
      );
      addTearDown(container.dispose);
      expect(
        container.read(syncStatusProvider).status,
        SyncUiStatus.success,
      );
    });

    test('pending changes surface as partialFailure', () {
      final ProviderContainer container = containerWith(
        SyncUiState(snapshot: const SyncQueueSnapshot(pending: 3)),
      );
      addTearDown(container.dispose);
      expect(
        container.read(syncStatusProvider).status,
        SyncUiStatus.partialFailure,
      );
      expect(container.read(syncStatusProvider).pendingCount, 3);
    });

    test('permanently failed changes surface as error', () {
      final ProviderContainer container = containerWith(
        SyncUiState(snapshot: const SyncQueueSnapshot(failed: 2)),
      );
      addTearDown(container.dispose);
      expect(
        container.read(syncStatusProvider).status,
        SyncUiStatus.error,
      );
      expect(container.read(syncStatusProvider).failedCount, 2);
    });

    test('an unresolved conflict surfaces as conflict', () {
      final ProviderContainer container = containerWith(
        const SyncUiState(pendingConflictCount: 1),
      );
      addTearDown(container.dispose);
      expect(
        container.read(syncStatusProvider).status,
        SyncUiStatus.conflict,
      );
      expect(container.read(syncStatusProvider).pendingConflictCount, 1);
    });

    test('never synced shows idle', () {
      final ProviderContainer container = containerWith(const SyncUiState());
      addTearDown(container.dispose);
      expect(
        container.read(syncStatusProvider).status,
        SyncUiStatus.idle,
      );
    });
  });

  group('SyncStatusChip widget', () {
    Future<void> pump(WidgetTester tester, SyncUiStatus status) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: SyncStatusChip(status: status))),
        ),
      );
    }

    testWidgets('renders the friendly label for every status — never raw errors',
        (WidgetTester tester) async {
      final List<(SyncUiStatus, String)> expectations = <(SyncUiStatus, String)>[
        (SyncUiStatus.success, 'Synced'),
        (SyncUiStatus.syncing, 'Syncing...'),
        (SyncUiStatus.offline, 'Offline'),
        (SyncUiStatus.error, 'Sync failed'),
        (SyncUiStatus.conflict, 'Conflict needs attention'),
        (SyncUiStatus.partialFailure, 'Pending changes'),
        (SyncUiStatus.idle, 'Not synced yet'),
      ];
      for (final (SyncUiStatus status, String label) in expectations) {
        await pump(tester, status);
        expect(find.text(label), findsOneWidget, reason: label);
        // No technical/raw text is ever rendered on the chip.
        expect(
          find.textContaining('postgrest', findRichText: false),
          findsNothing,
        );
      }
    });

    testWidgets('compact variant hides the label (subtle dashboard indicator)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SyncStatusChip(
                status: SyncUiStatus.success,
                compact: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Synced'), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });
  });

  group('manual sync (Sync now)', () {
    test('a running sync prevents a concurrent manual run', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          currentUserProvider.overrideWith(
            (ref) => const AppUser(id: 'user-1', displayName: 'Tester'),
          ),
          // Simulate an in-flight sync.
          syncControllerProvider.overrideWith(
            () => _FixedSyncController(
              const SyncUiState(activity: SyncActivity.syncing),
            ),
          ),
          syncStateRepositoryProvider.overrideWith(
            (ref) => _CountingStateRepo(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final _CountingStateRepo repo =
          container.read(syncStateRepositoryProvider) as _CountingStateRepo;

      await container.read(syncControllerProvider.notifier).runSync();

      // The guard returned before touching the sync pipeline.
      expect(repo.calls, 0);
      expect(
        container.read(syncControllerProvider).isSyncing,
        isTrue,
        reason: 'the in-flight run is untouched',
      );
    });

    test('offline run shows progress, completes without failure and records '
        'the sync time', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await databaseFactory.deleteDatabase(await _databasePath());
      final AppDatabase appDatabase = AppDatabase();
      final Database db = await appDatabase.database;
      await db.insert('users', <String, Object?>{
        'id': 'user-1',
        'name': 'Tester',
        'email': 't@x.com',
        'provider': 'email',
      });
      addTearDown(appDatabase.close);
      final _FakeSyncEngine engine = _FakeSyncEngine();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          currentUserProvider.overrideWith(
            (ref) => const AppUser(id: 'user-1', displayName: 'Tester'),
          ),
          appDatabaseProvider.overrideWith((ref) => appDatabase),
          syncStateRepositoryProvider.overrideWith(
            (ref) => _CompletedStateRepo(),
          ),
          syncEngineProvider.overrideWith((ref) => engine),
          syncConflictRepositoryProvider.overrideWith(
            (ref) => _FakeConflictRepo(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(syncControllerProvider.notifier).runSync();

      final SyncUiState ui = container.read(syncControllerProvider);
      expect(ui.isSyncing, isFalse, reason: 'completion resets activity');
      expect(ui.failure, isNull, reason: 'offline ack is not an error');
      // Offline path: the queue was processed locally, the transport sync was
      // not used (supabase is not configured in tests).
      expect(engine.processQueueCalls, 1);
      expect(engine.syncCalls, 0);
      expect(
        container.read(settingsControllerProvider).valueOrNull?.lastSyncAt,
        isNotNull,
        reason: 'last-sync time is recorded on completion',
      );
    });

    test('a failed run surfaces a friendly failure (retried later), never a '
        'technical error', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await databaseFactory.deleteDatabase(await _databasePath());
      final AppDatabase appDatabase = AppDatabase();
      final Database db = await appDatabase.database;
      await db.insert('users', <String, Object?>{
        'id': 'user-1',
        'name': 'Tester',
        'email': 't@x.com',
        'provider': 'email',
      });
      addTearDown(appDatabase.close);
      final _FakeSyncEngine engine = _FakeSyncEngine()
        ..processQueueResult = const SyncRunResult(failed: 1);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          currentUserProvider.overrideWith(
            (ref) => const AppUser(id: 'user-1', displayName: 'Tester'),
          ),
          appDatabaseProvider.overrideWith((ref) => appDatabase),
          syncStateRepositoryProvider.overrideWith(
            (ref) => _CompletedStateRepo(),
          ),
          syncEngineProvider.overrideWith((ref) => engine),
          syncConflictRepositoryProvider.overrideWith(
            (ref) => _FakeConflictRepo(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(syncControllerProvider.notifier).runSync();

      final SyncUiState ui = container.read(syncControllerProvider);
      expect(ui.failure, isA<SyncRunResult>());
      expect(ui.isSyncing, isFalse);
      // The derived status is the friendly "error" state, not raw text.
      expect(
        container.read(syncStatusProvider).status,
        SyncUiStatus.error,
      );
    });
  });
}