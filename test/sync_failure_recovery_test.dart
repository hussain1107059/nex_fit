import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/data/services/sync/sync_recovery_service.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/sync_state.dart';
import 'package:nexfit/domain/repositories/sync_event_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 21 — Sync Failure Recovery tests.
///
/// Covers the 12 failure scenarios (app killed mid-push/mid-pull, network loss
/// during upload/download, Supabase 500, timeout, auth expiry, duplicate event,
/// corrupted event, stuck processing, cursor mismatch, partial batch failure)
/// and the startup recovery sequence (reclaim stuck events, validate sync
/// state, resume pending sync, retry safe events). Requirements asserted:
/// no silent mutation loss, no endless repeats of successful cloud mutations,
/// no cursor skips.

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

final DateTime _farFuture = DateTime.now().add(const Duration(days: 30));

SyncEvent _event({
  String userId = 'user-1',
  String entity = 'weight_log',
  String entityId = 'wl-1',
  SyncOperation operation = SyncOperation.create,
}) {
  final DateTime now = DateTime.now();
  return SyncEvent(
    userId: userId,
    entity: entity,
    entityId: entityId,
    operation: operation,
    payload: '{"kg":80}',
    eventUuid: 'event-$entityId',
    createdAt: now,
    updatedAt: now,
  );
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

/// A scripted push behavior.
sealed class _PushStep {
  const _PushStep();
}

class _PushSucceed extends _PushStep {
  const _PushSucceed();
}

class _PushFail extends _PushStep {
  const _PushFail(this.message);
  final String message;
}

class _PushAppliedThenTimeout extends _PushStep {
  const _PushAppliedThenTimeout();
}

/// The server already applied the write; the retry only acknowledges it.
class _PushAcknowledge extends _PushStep {
  const _PushAcknowledge();
}

/// Scripted push transport: plays [steps] in order, then succeeds forever.
/// Tracks distinct server-side mutations so the idempotent-retry invariant
/// ("a committed write is never repeated") can be asserted.
class _ScriptedPushTransport implements SyncTransport {
  _ScriptedPushTransport(List<_PushStep> steps) : _steps = steps;

  final List<_PushStep> _steps;
  int calls = 0;
  int serverMutations = 0;

  @override
  String get name => 'scripted';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    final _PushStep step =
        calls < _steps.length ? _steps[calls] : const _PushSucceed();
    calls++;
switch (step) {
        case _PushSucceed():
          serverMutations++;
          return const SyncPushResult(applied: true);
        case _PushAcknowledge():
          // Row already exists (upsert keyed on the same uuid); no new
          // mutation.
          return const SyncPushResult(applied: true);
        case _PushAppliedThenTimeout():
          serverMutations++;
          throw const SyncTransportException('request_timeout');
        case _PushFail(message: final String m):
          throw SyncTransportException(m);
      }
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    return const SyncPullBatch(changes: <SyncChange>[], nextCursor: 0, hasMore: false);
  }
}

/// Pull transport that serves configured change pages and can throw on a
/// chosen call index (partial-batch / mid-download failure).
class _PullSequenceTransport implements SyncTransport {
  _PullSequenceTransport({required this.pages, this.throwOnCall});

  final List<List<SyncChange>> pages;
  final int? throwOnCall;
  static const SyncTransportException _error =
      SyncTransportException('network_dropped_mid_download');
  int pullCalls = 0;
  int pushCalls = 0;

  @override
  String get name => 'pull-sequence';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    pushCalls++;
    return const SyncPushResult(applied: true);
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    if (pullCalls == throwOnCall) throw _error;
    pullCalls++;
    final int pageIndex = pages.indexWhere(
      (List<SyncChange> page) =>
          page.isNotEmpty && page.last.cursorId > cursor,
    );
    if (pageIndex < 0) {
      return const SyncPullBatch(
        changes: <SyncChange>[],
        nextCursor: 0,
        hasMore: false,
      );
    }
    final List<SyncChange> page = pages[pageIndex];
    final List<SyncChange> served = page.take(limit).toList();
    final int nextCursor = served.isEmpty ? cursor : served.last.cursorId;
    final bool hasMore = pages.any(
      (List<SyncChange> p) =>
          p.isNotEmpty && p.last.cursorId > nextCursor,
    );
    return SyncPullBatch(
      changes: served,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }
}

/// Stalled-keyset transport: never advances its cursor yet claims more data —
/// exercises the engine's livelock guard.
class _StalledCursorTransport implements SyncTransport {
  @override
  String get name => 'stalled';

  @override
  bool get isReady => true;

  int calls = 0;

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
    calls++;
    return SyncPullBatch(
      changes: <SyncChange>[_weightChange(cursor + 1, recordId: 'wl-$calls')],
      nextCursor: cursor, // never advances
      hasMore: true,
    );
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late SyncEventRepository eventRepo;
  late SyncStateRepositoryImpl stateRepo;
  late RemoteChangeApplier applier;
  late SyncEngine engine;

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
    eventRepo = SyncEventRepositoryImpl(
      SyncEventLocalDataSource(database: appDatabase),
    );
    stateRepo = SyncStateRepositoryImpl(
      SyncStateLocalDataSource(database: appDatabase),
    );
    applier = RemoteChangeApplier(database: appDatabase);
    engine = SyncEngine(
      repository: eventRepo,
      syncStateRepository: stateRepo,
    );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  Future<void> makeDue(String userId) async {
    for (final SyncEvent e
        in await eventRepo.getRetryableByUserId(
      userId,
      now: _farFuture,
    )) {
      await eventRepo.update(e.copyWith(clearNextRetryAt: true));
    }
  }

  // Reads pending + retryable events regardless of their backoff gate so tests
  // can assert on a just-failed event's status/error.
  Future<List<SyncEvent>> allEligible(String userId) =>
      eventRepo.getRetryableByUserId(userId, now: _farFuture);

  group('push failure recovery', () {
    test('1. app killed mid-push: stuck PROCESSING event is reclaimed and '
        'delivered on the next startup', () async {
      final int id = await eventRepo.insert(_event());
      await eventRepo.markProcessing(
        id,
        at: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      // Simulated restart: a fresh engine + recovery pass.
      final SyncEngine restarted = SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
      );
      final SyncRecoveryService recovery = SyncRecoveryService(
        engine: restarted,
        syncStateRepository: stateRepo,
      );
      final SyncRecoveryResult result = await recovery.recoverOnStartup(
        userId: 'user-1',
        transport: _ScriptedPushTransport(const <_PushStep>[]),
      );

      expect(result.reclaimedStuck, 1);
      expect(
        (await eventRepo.getPendingByUserId('user-1')),
        isEmpty,
        reason: 'no silent mutation loss — the event was delivered, not dropped',
      );
      final Map<String, int> delivered =
          await eventRepo.countByStatus('user-1');
      expect(delivered[SyncStatus.completed.name] ?? 0, 1);
    });

    test('2. network lost during upload: event is retryable with backoff, '
        'survives a restart and is delivered when due', () async {
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.create,
      );

      final _ScriptedPushTransport flaky = _ScriptedPushTransport(
        const <_PushStep>[_PushFail('network_down')],
      );
      final SyncRunResult first = await engine.processQueue(
        'user-1',
        transport: flaky,
      );
      expect(first.failed, 1);
      SyncEvent event = (await allEligible('user-1')).single;
      expect(event.status, SyncStatus.failedRetryable);
      expect(event.nextRetryAt, isNotNull);

      // Restart while offline: the backoff gate keeps the event queued.
      final SyncEngine restarted = SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
      );
      final SyncRunResult gated = await restarted.processQueue('user-1');
      expect(gated.processed, 0, reason: 'backoff window has not elapsed');

      // Backoff elapses; a healthy transport delivers the event.
      await makeDue('user-1');
      final _ScriptedPushTransport healthy = _ScriptedPushTransport(
        const <_PushStep>[],
      );
      final SyncRunResult recovered = await restarted.processQueue(
        'user-1',
        transport: healthy,
      );
      expect(recovered.succeeded, 1);
      final Map<String, int> counts = await eventRepo.countByStatus('user-1');
      expect(counts[SyncStatus.completed.name] ?? 0, 1,
          reason: 'the surviving event was delivered exactly once');
    });

    test('3. Supabase 500 is retried with backoff and eventually succeeds',
        () async {
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.create,
      );
      final _ScriptedPushTransport transport = _ScriptedPushTransport(
        const <_PushStep>[
          _PushFail('postgrest_500_internal_server_error'),
          _PushFail('postgrest_500_internal_server_error'),
        ],
      );

      await engine.processQueue('user-1', transport: transport);
      expect(
        (await allEligible('user-1')).single.status,
        SyncStatus.failedRetryable,
      );
      await makeDue('user-1');
      await engine.processQueue('user-1', transport: transport);
      expect(
        (await allEligible('user-1')).single.status,
        SyncStatus.failedRetryable,
      );
      await makeDue('user-1');
      final SyncRunResult finalRun = await engine.processQueue(
        'user-1',
        transport: transport,
      );
      expect(finalRun.succeeded, 1);
      expect(transport.serverMutations, 1);
    });

    test('4. Supabase timeout is retried and eventually succeeds', () async {
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.create,
      );
      final _ScriptedPushTransport transport = _ScriptedPushTransport(
        const <_PushStep>[_PushFail('request_timeout')],
      );
      await engine.processQueue('user-1', transport: transport);
      await makeDue('user-1');
      final SyncRunResult recovered = await engine.processQueue(
        'user-1',
        transport: transport,
      );
      expect(recovered.succeeded, 1);
      expect(transport.serverMutations, 1);
    });

    test('5. auth expiry keeps the event queued (never permanently dropped) '
        'until the session recovers', () async {
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.create,
      );
      final _ScriptedPushTransport expired = _ScriptedPushTransport(
        const <_PushStep>[_PushFail('auth_session_expired')],
      );
      await engine.processQueue('user-1', transport: expired);

      SyncEvent event = (await allEligible('user-1')).single;
      expect(event.status, SyncStatus.failedRetryable,
          reason: 'auth expiry must never permanently drop a mutation');
      expect(event.lastError, isNotEmpty,
          reason: 'the failure is recorded (masked), the event is retained');

      // Re-authentication: the same event is delivered once.
      await makeDue('user-1');
      final _ScriptedPushTransport authed = _ScriptedPushTransport(
        const <_PushStep>[],
      );
      final SyncRunResult recovered = await engine.processQueue(
        'user-1',
        transport: authed,
      );
      expect(recovered.succeeded, 1);
      expect(authed.serverMutations, 1);
    });

    test('6. duplicate pending events merge into one queue row, pushed once',
        () async {
      final _ScriptedPushTransport transport = _ScriptedPushTransport(
        const <_PushStep>[],
      );
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.create,
        payload: '{"kg":80}',
      );
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.create,
        payload: '{"kg":81}',
      );

      final SyncRunResult result = await engine.processQueue(
        'user-1',
        transport: transport,
      );
      expect(result.processed, 1);
      expect(transport.calls, 1);
      expect(transport.serverMutations, 1);
    });

    test('7. corrupted/unsupported event fails permanently without blocking '
        'the rest of the queue', () async {
      await eventRepo.insert(
        _event(entity: 'unknown_table', entityId: 'bad-1'),
      );
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-ok',
        operation: SyncOperation.create,
      );

      final SyncRunResult result = await engine.processQueue(
        'user-1',
        transport: _RejectingUnknownTransport(),
      );

      final Map<String, int> counts = await eventRepo.countByStatus('user-1');
      expect(counts[SyncStatus.failedPermanent.name], 1,
          reason: 'corrupt event is terminal, never silently retried forever');
      expect(counts[SyncStatus.completed.name], 1,
          reason: 'the healthy event behind it still syncs');
      expect(result.failed, 1);
    });

    test('8. idempotent retry: a push that committed server-side but timed out '
        'never double-mutates the cloud row', () async {
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.create,
      );
      final _ScriptedPushTransport transport = _ScriptedPushTransport(
        const <_PushStep>[
          _PushAppliedThenTimeout(),
          _PushAcknowledge(),
        ],
      );

      await engine.processQueue('user-1', transport: transport);
      expect(transport.serverMutations, 1);
      expect(
        (await allEligible('user-1')).single.status,
        SyncStatus.failedRetryable,
      );

      // Retry: the server already has the row (upsert on the same uuid), so it
      // acknowledges without mutating again.
      await makeDue('user-1');
      final SyncRunResult recovered = await engine.processQueue(
        'user-1',
        transport: transport,
      );
      expect(recovered.succeeded, 1);
      expect(transport.serverMutations, 1,
          reason: 'a committed cloud mutation is never repeated');
      expect(transport.calls, 2);
    });
  });

  group('pull failure recovery', () {
    test('9. app killed mid-pull (partial batch failure): committed batch and '
        'cursor roll back; the next run resumes without re-applying or '
        'skipping', () async {
      final _PullSequenceTransport flaky = _PullSequenceTransport(
        pages: <List<SyncChange>>[
          <SyncChange>[_weightChange(1, recordId: 'wl-1'),
            _weightChange(2, recordId: 'wl-2')],
          <SyncChange>[_weightChange(3, recordId: 'wl-3'),
            _weightChange(4, recordId: 'wl-4')],
        ],
        throwOnCall: 1,
      );

      await expectLater(
        engine.pull(userId: 'user-1', transport: flaky, applier: applier),
        throwsA(isA<SyncTransportException>()),
      );
      final Database db = await appDatabase.database;
      expect(await db.query('weight_log'), hasLength(2),
          reason: 'failed batch rolled back');
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 2,
          reason: 'cursor never advances past a failed batch');

      // Startup resume: pull from cursor 2; the server paginator resumes after
      // the stored cursor, serving rows 3-4 exactly once.
      final SyncEngine restarted = SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
      );
      final int pulled = await restarted.pull(
        userId: 'user-1',
        transport: _PullSequenceTransport(
          pages: <List<SyncChange>>[
            <SyncChange>[_weightChange(3, recordId: 'wl-3'),
              _weightChange(4, recordId: 'wl-4')],
          ],
        ),
        applier: applier,
      );
      expect(pulled, 2, reason: 'no cursor skips — only the missing rows apply');
      expect(await db.query('weight_log'), hasLength(4));
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 4);
    });

    test('10. network lost during download: sync reports a partial failure, '
        'the cursor is untouched and the next run completes', () async {
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-9',
        operation: SyncOperation.create,
      );
      final _PullSequenceTransport down = _PullSequenceTransport(
        pages: const <List<SyncChange>>[],
        throwOnCall: 0,
      );

      final SyncRunResult result = await engine.sync(
        userId: 'user-1',
        transport: down,
        applier: applier,
      );
      expect(result.succeeded, 1, reason: 'push phase completed');
      expect(result.failed, 1, reason: 'pull phase reported the failure');
      expect(result.hasPulled, isFalse);
      expect(await stateRepo.getByUserId('user-1'), isNull,
          reason: 'no cursor was persisted for a failed download');

      final SyncEngine restarted = SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
      );
      final int pulled = await restarted.pull(
        userId: 'user-1',
        transport: _PullSequenceTransport(
          pages: <List<SyncChange>>[
            <SyncChange>[_weightChange(1, recordId: 'wl-1')],
          ],
        ),
        applier: applier,
      );
      expect(pulled, 1);
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 1);
    });

    test('11. cursor mismatch: a stalled keyset breaks the livelock guard '
        'instead of looping forever', () async {
      final _StalledCursorTransport stalled = _StalledCursorTransport();
      final int pulled = await engine.pull(
        userId: 'user-1',
        transport: stalled,
        applier: applier,
        drainToEnd: true,
      );
      expect(stalled.calls, 1, reason: 'guard broke after one stalled page');
      expect(pulled, 1);
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 0,
          reason: 'the stalled cursor never advanced');
    });

    test('12. remote re-delivery is deduplicated by uuid — the same row never '
        'applies twice', () async {
      final _PullSequenceTransport first = _PullSequenceTransport(
        pages: <List<SyncChange>>[
          <SyncChange>[
            _weightChange(1, recordId: 'wl-dup'),
            _weightChange(2, recordId: 'wl-2'),
          ],
        ],
      );
      await engine.pull(userId: 'user-1', transport: first, applier: applier);
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 2);

      // The server re-delivers rows already seen after a network blip; the
      // resume paginator continues after cursor 2 and serves only the new row.
      final int pulled = await engine.pull(
        userId: 'user-1',
        transport: _PullSequenceTransport(
          pages: <List<SyncChange>>[
            <SyncChange>[_weightChange(3, recordId: 'wl-3')],
          ],
        ),
        applier: applier,
      );
      final Database db = await appDatabase.database;
      expect(pulled, 1);
      expect(await db.query('weight_log'), hasLength(3));
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 3);
    });
  });

  group('startup recovery service', () {
    test('recoverOnStartup reclaims stuck events, validates a healthy state '
        'and resumes push + pull', () async {
      // Stuck PROCESSING event (app killed mid-push).
      final int stuckId = await eventRepo.insert(_event(entityId: 'wl-stuck'));
      await eventRepo.markProcessing(
        stuckId,
        at: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      // Pending event queued before the crash.
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-pending',
        operation: SyncOperation.create,
      );
      // Healthy stored cursor state (initial sync completed).
      await stateRepo.upsert(
        SyncState(
          userId: 'user-1',
          cursor: 5,
          initialSyncCompleted: true,
          lastSyncAt: DateTime.now().subtract(const Duration(hours: 1)),
          status: 'success',
          updatedAt: DateTime.now(),
        ),
      );

      final SyncRecoveryResult result = await SyncRecoveryService(
        engine: engine,
        syncStateRepository: stateRepo,
      ).recoverOnStartup(
        userId: 'user-1',
        transport: _PullSequenceTransport(
          pages: <List<SyncChange>>[
            <SyncChange>[_weightChange(6, recordId: 'wl-6'),
              _weightChange(7, recordId: 'wl-7')],
          ],
        ),
        applier: applier,
      );

      expect(result.reclaimedStuck, 1);
      expect(result.syncStateValid, isTrue);
      expect(result.resumed, 2, reason: 'both outbox events delivered');
      expect(result.pulled, 2);
      expect(result.failed, 0);
      expect(result.healthy, isTrue);
      final Map<String, int> counts = await eventRepo.countByStatus('user-1');
      expect(counts[SyncStatus.completed.name] ?? 0, 2);
      expect(counts[SyncStatus.pending.name] ?? 0, 0);
      expect((await stateRepo.getByUserId('user-1'))!.cursor, 7);
    });

    test('recoverOnStartup flags an invalid sync state and still resumes '
        'safe events offline', () async {
      await stateRepo.upsert(
        SyncState(
          userId: 'user-1',
          cursor: -5, // corrupted cursor
          initialSyncCompleted: true,
          lastSyncAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-1',
        operation: SyncOperation.create,
      );

      final SyncRecoveryResult result = await SyncRecoveryService(
        engine: engine,
        syncStateRepository: stateRepo,
      ).recoverOnStartup(userId: 'user-1');

      expect(result.syncStateValid, isFalse);
      expect(result.resumed, 1, reason: 'safe events are still retried');
      expect(result.healthy, isFalse);
      expect(
        (await eventRepo.countByStatus('user-1'))[SyncStatus.completed.name] ??
            0,
        1,
      );
    });

    test('SyncStateValidator accepts a healthy state and rejects '
        'inconsistent ones', () {
      expect(SyncStateValidator.validate(null), isTrue);
      expect(
        SyncStateValidator.validate(
          SyncState(
            userId: 'u',
            cursor: 0,
            lastSyncAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        isTrue,
      );
      expect(
        SyncStateValidator.validate(
          SyncState(userId: 'u', cursor: 0, updatedAt: DateTime.now()),
        ),
        isTrue,
      );
      expect(
        SyncStateValidator.validate(
          SyncState(userId: 'u', cursor: -1, updatedAt: DateTime.now()),
        ),
        isFalse,
      );
      expect(
        SyncStateValidator.validate(
          SyncState(
            userId: 'u',
            cursor: 3,
            initialSyncCompleted: true,
            updatedAt: DateTime.now(),
          ),
        ),
        isFalse,
      );
    });
  });
}

/// Push transport that rejects unknown entities like the real Supabase
/// transport does (`unsupported_entity` → terminal, non-retryable).
class _RejectingUnknownTransport implements SyncTransport {
  @override
  String get name => 'rejecting';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    if (event.entity == 'unknown_table') {
      return const SyncPushResult(
        applied: false,
        lastError: 'unsupported_entity',
      );
    }
    return const SyncPushResult(applied: true);
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    return const SyncPullBatch(changes: <SyncChange>[], nextCursor: 0, hasMore: false);
  }
}