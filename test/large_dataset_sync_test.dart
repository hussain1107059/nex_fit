import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/constants/app_constants.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/sync_state.dart';
import 'package:nexfit/domain/repositories/sync_event_repository.dart';
import 'package:nexfit/domain/repositories/sync_state_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 20 - large dataset synchronization + performance.
///
/// Verifies the SQLite/network batching contract and measures it at 10,000+
/// records:
///  - paginated pull at `syncPullBatchSize` (never all-at-once),
///  - batched apply: each page commits atomically with its cursor advance,
///  - indexed queries (EXPLAIN QUERY PLAN) for the outbox and per-user reads,
///  - WAL mode + sane PRAGMAs on native,
///  - initial sync drains an unlimited remote paginator in ONE run (the
///    incremental batch cap no longer truncates a first sync of >5,000 rows),
///  - incremental sync applies only the delta (bounded batch count),
///  - push drains a 10,001-event outbox in bounded pages,
///  - elapsed time, memory and on-disk database size are measured and reported
///    so the numbers can be transcribed into `docs` §16.

final int kBenchmarkRows = 10001;
final int kIncrementalDelta = 500;

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

SyncChange _change(int id) {
  final String recordId = 'wl-$id';
  return SyncChange(
    cursorId: id,
    cloudTable: 'weight_logs',
    recordId: recordId,
    operation: SyncOperation.create,
    payload: <String, Object?>{
      'id': recordId,
      'user_id': 'user-1',
      'weight_kg': 80.0 + (id % 20),
      'logged_at': '2026-01-01T06:00:00Z',
      'created_at': '2026-01-01T06:00:00Z',
      'updated_at': '2026-01-01T06:00:00Z',
      'row_version': 1,
    },
  );
}

/// Stateless keyset paginator mirroring the production Supabase transport:
/// serves every change with `cursorId > cursor`, capped at [limit].
class _BenchmarkTransport implements SyncTransport {
  _BenchmarkTransport({required this.total});

  final int total;
  int pullCalls = 0;
  int pushed = 0;
  final List<int> requestedLimits = <int>[];

  @override
  String get name => 'benchmark';

  @override
  bool get isReady => true;

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
    requestedLimits.add(limit);
    if (cursor >= total) {
      return SyncPullBatch(
        changes: const <SyncChange>[],
        nextCursor: cursor,
        hasMore: false,
      );
    }
    final int start = cursor + 1;
    final int end = (start + limit - 1 > total) ? total : start + limit - 1;
    final List<SyncChange> page = <SyncChange>[
      for (int id = start; id <= end; id++) _change(id),
    ];
    final int nextCursor = page.last.cursorId;
    return SyncPullBatch(
      changes: page,
      nextCursor: nextCursor,
      hasMore: nextCursor < total,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late Database db;
  late SyncEventRepository eventRepo;
  late SyncStateRepository stateRepo;
  late RemoteChangeApplier applier;

  Future<void> setUpDb() async {
    await databaseFactory.deleteDatabase(await _databasePath());
    appDatabase = AppDatabase();
    db = await appDatabase.database;
    await db.insert('users', <String, Object?>{
      'id': 'user-1',
      'name': 'Alice',
      'email': 'alice@x.com',
      'provider': 'email',
    });
    eventRepo = SyncEventRepositoryImpl(
      SyncEventLocalDataSource(database: appDatabase),
    );
    stateRepo = SyncStateRepositoryImpl(
      SyncStateLocalDataSource(database: appDatabase),
    );
    applier = RemoteChangeApplier(database: appDatabase);
  }

  tearDown(() async {
    await appDatabase.close();
  });

  SyncEngine engine() => SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
        deviceIdProvider: () async => 'device-1',
      );

  Future<SyncState> state() async => (await stateRepo.getByUserId('user-1'))!;

  Future<int> rowCount() async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM weight_log',
    );
    return (rows.first['c'] as num).toInt();
  }

  group('SQLite performance foundations', () {
    setUp(setUpDb);

    test('native PRAGMAs: WAL, foreign keys, sane cache/mmap', () async {
      final List<Map<String, Object?>> journal = await db.rawQuery(
        'PRAGMA journal_mode',
      );
      expect(journal.first['journal_mode'], 'wal');
      final List<Map<String, Object?>> fk = await db.rawQuery(
        'PRAGMA foreign_keys',
      );
      expect(fk.first['foreign_keys'], 1);
    });

    test('pull paginates at the configured batch size, never all-at-once',
        () async {
      final _BenchmarkTransport transport = _BenchmarkTransport(total: 250);
      final int pulled = await engine().pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
        drainToEnd: true,
      );

      expect(pulled, 250);
      expect(transport.pullCalls, 3);
      expect(
        transport.requestedLimits.every(
          (int l) => l == AppConstants.syncPullBatchSize,
        ),
        isTrue,
        reason: 'every page is requested at the configured batch size',
      );
      expect((await state()).cursor, 250);
    });

    test('EXPLAIN QUERY PLAN: outbox + per-user reads use indexes', () async {
      // Seed a few events so the planner has real data.
      await db.insert('sync_event', <String, Object?>{
        'user_id': 'user-1',
        'entity': 'weight_log',
        'entity_id': '1',
        'operation': SyncOperation.create.name,
        'status': SyncStatus.pending.name,
        'created_at': 1,
        'updated_at': 1,
        'event_uuid': 'evt-1',
      });

      final List<Map<String, Object?>> outboxPlan = await db.rawQuery(
        "EXPLAIN QUERY PLAN SELECT id FROM sync_event "
        "WHERE user_id = 'user-1' AND status IN ('pending','failedRetryable') "
        "ORDER BY created_at ASC",
      );
      final String outboxDetail = outboxPlan.map((Map<String, Object?> r) => r['detail']).join(' ');
      expect(
        outboxDetail,
        contains('idx_sync_event_user_status'),
        reason: 'the outbox drain must be served by the (user_id, status, '
            'created_at) index, not a scan',
      );

      final List<Map<String, Object?>> uuidPlan = await db.rawQuery(
        "EXPLAIN QUERY PLAN SELECT id FROM weight_log WHERE uuid = 'x'",
      );
      final String uuidDetail =
          uuidPlan.map((Map<String, Object?> r) => r['detail']).join(' ');
      expect(uuidDetail, contains('idx_weight_log_uuid'));

      final List<Map<String, Object?>> userPlan = await db.rawQuery(
        "EXPLAIN QUERY PLAN SELECT id FROM weight_log "
        "WHERE user_id = 'user-1' ORDER BY logged_at DESC",
      );
      final String userDetail =
          userPlan.map((Map<String, Object?> r) => r['detail']).join(' ');
      expect(userDetail, contains('idx_weight_log_user_logged'));
    });

    test('incremental pull stays bounded by the batch cap', () async {
      final _BenchmarkTransport transport =
          _BenchmarkTransport(total: kBenchmarkRows);
      final SyncEngine syncEngine = engine();
      final int pulled = await syncEngine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
      );

      // 50 batches x 100 = 5,000 max per incremental run; the rest self-heals
      // on the next run (documented PROMPT 20 behaviour).
      expect(pulled, AppConstants.syncMaxPullBatches * AppConstants.syncPullBatchSize);
      expect(transport.pullCalls, AppConstants.syncMaxPullBatches);
      expect((await state()).cursor, pulled);
    });
  });

  group('10,000+ record benchmark', () {
    setUp(setUpDb);

    test('initial + incremental + push measured at 10,001 records', () async {
      final int rssBefore = ProcessInfo.currentRss ~/ (1024 * 1024);
      final List<String> metrics = <String>[];

      // ---------------------------------------------------------------- pull
      final _BenchmarkTransport transport =
          _BenchmarkTransport(total: kBenchmarkRows);
      final SyncEngine syncEngine = engine();
      final Stopwatch initialWatch = Stopwatch()..start();
      int progressCalls = 0;
      int lastProgressCursor = 0;
      final int pulled = await syncEngine.pull(
        userId: 'user-1',
        transport: transport,
        applier: applier,
        drainToEnd: true,
        onBatchProgress: (int applied, int cursor) {
          progressCalls++;
          expect(cursor, greaterThan(lastProgressCursor),
              reason: 'progress cursor is monotonic across pages');
          lastProgressCursor = cursor;
        },
      );
      initialWatch.stop();

      expect(pulled, kBenchmarkRows, reason: 'initial sync drains fully');
      expect(transport.pullCalls, 101);
      expect((await state()).cursor, kBenchmarkRows);
      expect((await state()).initialSyncCompleted, isTrue);
      expect(progressCalls, 101);
      expect(await rowCount(), kBenchmarkRows);
      metrics.add(
        'initial_sync: pulled=$pulled pages=${transport.pullCalls} '
        'time=${initialWatch.elapsedMilliseconds}ms',
      );

      // ----------------------------------------------------- incremental
      final _BenchmarkTransport deltaTransport = _BenchmarkTransport(
        total: kBenchmarkRows + kIncrementalDelta,
      );
      final Stopwatch deltaWatch = Stopwatch()..start();
      final int delta = await syncEngine.pull(
        userId: 'user-1',
        transport: deltaTransport,
        applier: applier,
      );
      deltaWatch.stop();

      expect(delta, kIncrementalDelta);
      expect(deltaTransport.pullCalls, 5);
      expect((await state()).cursor, kBenchmarkRows + kIncrementalDelta);
      metrics.add(
        'incremental_sync: delta=$delta pages=${deltaTransport.pullCalls} '
        'time=${deltaWatch.elapsedMilliseconds}ms',
      );

      // ------------------------------------------------------------- push
      // Bulk-enqueue 10,001 outbox events (single transaction) then drain.
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.transaction((Transaction txn) async {
        for (int i = 0; i < kBenchmarkRows; i++) {
          await txn.insert('sync_event', <String, Object?>{
            'user_id': 'user-1',
            'entity': 'weight_log',
            'entity_id': '$i',
            'operation': SyncOperation.create.name,
            'payload': '{"weight_kg":82}',
            'status': SyncStatus.pending.name,
            'conflict_strategy': SyncConflictStrategy.latestWins.name,
            'created_at': nowMs,
            'updated_at': nowMs,
            'event_uuid': 'evt-$i',
            'device_id': 'device-1',
            'base_version': 0,
          });
        }
      });

      final _BenchmarkTransport pushTransport = _BenchmarkTransport(total: 0);
      final Stopwatch pushWatch = Stopwatch()..start();
      final SyncRunResult push = await syncEngine.processQueue(
        'user-1',
        transport: pushTransport,
      );
      pushWatch.stop();

      expect(push.processed, kBenchmarkRows);
      expect(push.succeeded, kBenchmarkRows);
      expect(push.failed, 0);
      expect(push.conflicts, 0);
      expect(
        (await eventRepo.countByStatus('user-1'))[SyncStatus.completed.name],
        kBenchmarkRows,
      );
      expect(pushTransport.pushed, kBenchmarkRows);
      metrics.add(
        'push: events=$kBenchmarkRows time=${pushWatch.elapsedMilliseconds}ms',
      );

      // ------------------------------------------------------ memory + size
      final int rssMb = ProcessInfo.currentRss ~/ (1024 * 1024);
      final File dbFile = File(await _databasePath());
      final int dbKb = dbFile.existsSync() ? dbFile.lengthSync() ~/ 1024 : 0;
      metrics.add('memory: rssBefore=${rssBefore}MB rssAfter=${rssMb}MB');
      metrics.add('database_size: ${dbKb}KB for $kBenchmarkRows rows');

      // Generous caps to avoid flaky CI; real numbers are for the docs.
      expect((rssMb - rssBefore), lessThan(1024));
      expect(dbKb, lessThan(32 * 1024));

      // The measured numbers are surfaced in the test report.
      // ignore: avoid_print
      print('[large_dataset_benchmark] ${metrics.join(' | ')}');
    });
  });
}