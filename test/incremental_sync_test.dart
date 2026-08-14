import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/incremental_sync_coordinator.dart';
import 'package:nexfit/data/services/sync/realtime_sync_notifier.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/sync_state.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 18 — Incremental Sync + Realtime Notification tests.
///
/// Covers the cursor flow (start at 0, resume at N, cursor only advances after a
/// committed batch), batching (large change sets are pulled page by page, never
/// loaded wholesale), Realtime as a notification-only accelerator (duplicate
/// events coalesce, missed events are recovered by the next trigger), the
/// offline -> online recovery path and app-restart cursor persistence.

const Duration _debounce = Duration(milliseconds: 200);

final List<String> _realtimeTables = RealtimeSyncNotifier.realtimeTables;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeGateway implements RealtimeChannelGateway {
  final List<String> subscribed = <String>[];
  bool active = false;
  void Function()? _onEvent;

  @override
  bool get isActive => active;

  @override
  void subscribeToChanges({
    required List<String> tables,
    required void Function() onEvent,
  }) {
    subscribed.addAll(tables);
    active = true;
    _onEvent = onEvent;
  }

  @override
  void close() {
    active = false;
    _onEvent = null;
  }

  void fire() => _onEvent?.call();
}

/// Stateless paginated pull transport: serves every [SyncChange] with a cursor
/// id greater than the requested cursor. `hasMore` mirrors the real transport.
class _FakePullTransport implements SyncTransport {
  _FakePullTransport({required this._changes, this.ready = true});

  final List<SyncChange> _changes;
  final bool ready;
  int pullCalls = 0;
  int pushed = 0;
  int maxRequestedLimit = 0;

  @override
  String get name => 'fake';

  @override
  bool get isReady => ready;

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    pushed++;
    return const SyncPushResult(applied: true);
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    pullCalls++;
    if (limit > maxRequestedLimit) maxRequestedLimit = limit;
    final List<SyncChange> filtered = _changes
        .where((SyncChange c) => c.cursorId > cursor)
        .toList();
    final List<SyncChange> page = filtered.take(limit).toList();
    final int nextCursor = page.isEmpty ? cursor : page.last.cursorId;
    return SyncPullBatch(
      changes: page,
      nextCursor: nextCursor,
      hasMore: filtered.length > limit,
    );
  }
}

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

SyncChange _weightChange(
  int cursorId, {
  String recordId = 'wl-uuid-1',
}) {
  return SyncChange(
    cursorId: cursorId,
    cloudTable: 'weight_logs',
    recordId: recordId,
    operation: SyncOperation.create,
    payload: <String, Object?>{
      'id': recordId,
      'user_id': 'user-1',
      'weight_kg': 82.5,
      'logged_at': '2026-01-01T06:00:00Z',
      'created_at': '2026-01-01T06:00:00Z',
      'updated_at': '2026-01-01T06:00:00Z',
      'row_version': 1,
    },
  );
}

// ---------------------------------------------------------------------------
// Coordinator — debounce, single-flight, gating, flush
// ---------------------------------------------------------------------------

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('coordinator: debounce + dedup', () {
    test('bursts of realtime events coalesce into a single run', () {
      fakeAsync((FakeAsync async) {
        int runs = 0;
        final IncrementalSyncCoordinator coordinator =
            IncrementalSyncCoordinator(
              canSync: () => true,
              onSync: (_) async => runs++,
              debounce: _debounce,
            );

        for (int i = 0; i < 10; i++) {
          coordinator.requestSync(SyncTrigger.realtime);
        }
        async.elapse(_debounce * 2);
        expect(runs, 1);

        // A request arriving later starts a fresh, separate run.
        coordinator.requestSync(SyncTrigger.realtime);
        async.elapse(_debounce * 2);
        expect(runs, 2);
        coordinator.dispose();
      });
    });

    test('requests during a running sync are queued and run after it finishes',
        () {
      fakeAsync((FakeAsync async) {
        final Completer<void> gate = Completer<void>();
        int runs = 0;
        final IncrementalSyncCoordinator coordinator =
            IncrementalSyncCoordinator(
              canSync: () => true,
              onSync: (_) async {
                runs++;
                await gate.future;
              },
              debounce: Duration.zero,
            );

        coordinator.requestSync(SyncTrigger.startup);
        async.elapse(Duration.zero);
        expect(coordinator.isRunning, isTrue);

        // A change arrives mid-run: it must not be lost.
        coordinator.requestSync(SyncTrigger.realtime);
        async.elapse(_debounce);
        expect(runs, 1);

        gate.complete();
        async.flushMicrotasks();
        expect(runs, 2);
        coordinator.dispose();
      });
    });

    test('requests are dropped while canSync is false (offline / signed out)',
        () {
      fakeAsync((FakeAsync async) {
        int runs = 0;
        bool signedIn = false;
        final IncrementalSyncCoordinator coordinator =
            IncrementalSyncCoordinator(
              canSync: () => signedIn,
              onSync: (_) async => runs++,
              debounce: _debounce,
            );

        coordinator.requestSync(SyncTrigger.realtime);
        coordinator.requestSync(SyncTrigger.networkRecovery);
        async.elapse(_debounce * 2);
        expect(runs, 0);

        // Network recovers: the pending recovery now runs.
        signedIn = true;
        coordinator.requestSync(SyncTrigger.networkRecovery);
        async.elapse(_debounce * 2);
        expect(runs, 1);
        coordinator.dispose();
      });
    });

    test('flush executes a pending request immediately', () {
      fakeAsync((FakeAsync async) {
        int runs = 0;
        final IncrementalSyncCoordinator coordinator =
            IncrementalSyncCoordinator(
              canSync: () => true,
              onSync: (_) async => runs++,
              debounce: const Duration(minutes: 1),
            );

        coordinator.requestSync(SyncTrigger.startup);
        expect(coordinator.pendingTrigger, SyncTrigger.startup);
        unawaited(coordinator.flush());
        async.flushMicrotasks();
        expect(runs, 1);
        expect(coordinator.pendingTrigger, isNull);
        coordinator.dispose();
      });
    });

    test('dispose drops pending work and cancels the timer', () {
      fakeAsync((FakeAsync async) {
        int runs = 0;
        final IncrementalSyncCoordinator coordinator =
            IncrementalSyncCoordinator(
              canSync: () => true,
              onSync: (_) async => runs++,
              debounce: _debounce,
            );

        coordinator.requestSync(SyncTrigger.resume);
        coordinator.dispose();
        async.elapse(_debounce * 2);
        expect(runs, 0);
      });
    });
  });

  group('realtime notifier: notification-only', () {
    test('subscribes to the realtime tables and forwards change signals', () {
      final _FakeGateway gateway = _FakeGateway();
      final RealtimeSyncNotifier notifier = RealtimeSyncNotifier(gateway: gateway);
      int notifications = 0;
      notifier.onRemoteChange = () => notifications++;

      notifier.attach();
      expect(notifier.isActive, isTrue);
      expect(gateway.subscribed, containsAll(_realtimeTables));

      // Realtime only signals; it never delivers/apply rows itself.
      gateway.fire();
      gateway.fire();
      expect(notifications, 2);

      notifier.detach();
      expect(notifier.isActive, isFalse);
      gateway.fire();
      expect(notifications, 2);
    });

    test('attach is idempotent and detach unsubscribes', () {
      final _FakeGateway gateway = _FakeGateway();
      final RealtimeSyncNotifier notifier = RealtimeSyncNotifier(gateway: gateway);

      notifier.attach();
      notifier.attach();
      expect(gateway.subscribed, hasLength(_realtimeTables.length));
      expect(notifier.isActive, isTrue);

      notifier.detach();
      expect(gateway.isActive, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Engine — cursor flow, batching, restart, recovery
  // -------------------------------------------------------------------------

  group('incremental sync engine', () {
    late AppDatabase appDatabase;
    late SyncEngine engine;
    late SyncStateRepositoryImpl stateRepo;
    late RemoteChangeApplier applier;

    setUp(() async {
      await databaseFactory.deleteDatabase(await _databasePath());
      appDatabase = AppDatabase();
      await appDatabase.database;
      final Database db = await appDatabase.database;
      await db.insert('users', <String, Object?>{
        'id': 'user-1',
        'name': 'Tester',
        'email': 't@x.com',
        'provider': 'email',
      });
      stateRepo = SyncStateRepositoryImpl(
        SyncStateLocalDataSource(database: appDatabase),
      );
      applier = RemoteChangeApplier(database: appDatabase);
      engine = SyncEngine(
        repository: SyncEventRepositoryImpl(
          SyncEventLocalDataSource(database: appDatabase),
        ),
        syncStateRepository: stateRepo,
      );
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('cursor 0 pulls everything and advances the cursor only after commit',
        () async {
      final _FakePullTransport transport = _FakePullTransport(
        changes: <SyncChange>[
          _weightChange(1, recordId: 'wl-1'),
          _weightChange(2, recordId: 'wl-2'),
        ],
      );

      final int pulled = await engine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );

      expect(pulled, 2);
      final Database db = await appDatabase.database;
      expect(await db.query('weight_log'), hasLength(2));
      final SyncState? state = await stateRepo.getByUserId('user-1');
      expect(state, isNotNull);
      expect(state!.cursor, 2);
      expect(state.initialSyncCompleted, isTrue);
    });

    test('cursor N resumes — the same change never applies twice (dedup)',
        () async {
      final _FakePullTransport transport = _FakePullTransport(
        changes: <SyncChange>[
          _weightChange(5, recordId: 'wl-1'),
          _weightChange(6, recordId: 'wl-2'),
          _weightChange(7, recordId: 'wl-3'),
        ],
      );

      await engine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 7);
      final Database db = await appDatabase.database;
      expect(await db.query('weight_log'), hasLength(3));

      // Second run starts at cursor 7; re-delivered rows 5/6 are ignored, row 8
      // is applied exactly once.
      final int pulled = await engine.pull(
        userId: 'user-1',
        transport: _FakePullTransport(
          changes: <SyncChange>[
            _weightChange(5, recordId: 'wl-1'),
            _weightChange(6, recordId: 'wl-2'),
            _weightChange(8, recordId: 'wl-4'),
          ],
        ),
        applier: applier,
      );

      expect(pulled, 1);
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 8);
      expect(await db.query('weight_log'), hasLength(4));
    });

    test('large change set pulls in bounded batches, not all at once',
        () async {
      final List<SyncChange> changes = <SyncChange>[
        for (int i = 1; i <= 250; i++)
          _weightChange(i, recordId: 'wl-$i'),
      ];
      final _FakePullTransport transport = _FakePullTransport(changes: changes);

      final int pulled = await engine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );

      expect(pulled, 250);
      final Database db = await appDatabase.database;
      expect(await db.query('weight_log'), hasLength(250));
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 250);
      // 250 rows in pages of 100 => exactly 3 requests, never the full set.
      expect(transport.pullCalls, 3);
      expect(transport.maxRequestedLimit, lessThanOrEqualTo(100));
    });

    test('app restart + missed realtime: a new engine recovers from the cursor',
        () async {
      // Run 1 (this "session"): rows 1-2 pulled, realtime for row 3 is missed
      // because the app is closed.
      await engine.pull(
        userId: 'user-1',
        transport: _FakePullTransport(
          changes: <SyncChange>[
            _weightChange(1, recordId: 'wl-1'),
            _weightChange(2, recordId: 'wl-2'),
          ],
        ),
        applier: applier,
      );
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 2);

      // App restart: a fresh engine over the same persisted database. The
      // startup trigger pulls whatever happened while the app was closed.
      final SyncEngine restarted = SyncEngine(
        repository: SyncEventRepositoryImpl(
          SyncEventLocalDataSource(database: appDatabase),
        ),
        syncStateRepository: stateRepo,
      );
      final int recovered = await restarted.pull(
        userId: 'user-1',
        transport: _FakePullTransport(
          changes: <SyncChange>[
            _weightChange(1, recordId: 'wl-1'),
            _weightChange(2, recordId: 'wl-2'),
            _weightChange(3, recordId: 'wl-3'),
          ],
        ),
        applier: applier,
      );

      expect(recovered, 1);
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 3);
      final Database db = await appDatabase.database;
      expect(await db.query('weight_log'), hasLength(3));
    });

    test('full sync pushes the outbox then pulls remote rows', () async {
      // Local mutation queued while offline.
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-9',
        operation: SyncOperation.create,
      );

      final SyncRunResult result = await engine.sync(
        userId: 'user-1',
        transport: _FakePullTransport(
          changes: <SyncChange>[
            _weightChange(10, recordId: 'wl-10'),
          ],
        ),
        applier: applier,
      );

      expect(result.succeeded, 1, reason: 'outbox event pushed');
      expect(result.pulled, 1, reason: 'remote row pulled');
      expect(result.hasPulled, isTrue);
      final Database db = await appDatabase.database;
      expect(await db.query('weight_log'), hasLength(1));
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 10);
    });

    test('offline: processQueue acks pending events locally, no network call',
        () async {
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-9',
        operation: SyncOperation.create,
      );

      final _FakePullTransport transport = _FakePullTransport(
        changes: const <SyncChange>[],
        ready: false,
      );
      final SyncRunResult result = await engine.processQueue(
        'user-1',
        transport: transport,
      );

      expect(result.succeeded, 1, reason: 'acked locally');
      expect(transport.pushed, 0, reason: 'never touched the network');
      expect(await stateRepo.getByUserId('user-1'), isNull,
          reason: 'no pull, cursor untouched');
    });

    test('uncommitted batch rolls back and never advances the cursor', () async {
      final _FakePullTransport transport = _FakePullTransport(
        changes: <SyncChange>[
          _weightChange(1, recordId: 'wl-1'),
          _weightChange(2, recordId: 'wl-2', ),
        ],
      );
      await engine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 2);

      // A pull that fails mid-batch must keep prior data and the cursor.
      final _FailingTransport failing = _FailingTransport();
      await expectLater(
        engine.pull(userId: 'user-1', transport: failing, applier: applier),
        throwsA(isA<SyncTransportException>()),
      );
      final Database db = await appDatabase.database;
      expect(await db.query('weight_log'), hasLength(2));
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 2);
    });
  });
}

class _FailingTransport implements SyncTransport {
  @override
  String get name => 'failing';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    return const SyncPushResult(applied: true);
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    throw const SyncTransportException('network_down');
  }
}
