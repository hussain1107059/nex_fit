import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/initial_sync_service.dart';
import 'package:nexfit/data/services/sync/local_data_ownership.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/sync_state.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 17 — Initial User Synchronization tests.
///
/// Covers the first-time flow (ensure profile -> detect initial sync -> pull
/// cloud rows -> push own pending records -> mark complete), the safe handling
/// of pre-existing local data (never deleted, never silently uploaded for
/// another account, orphans only adopted through explicit opt-in), the
/// offline / partial-download / retry paths and per-user isolation on a shared
/// device.

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakePullTransport implements SyncTransport {
  _FakePullTransport({
    required this.changes,
    this.ready = true,
    this.failOnPullCall = -1,
  });

  final List<SyncChange> changes;
  final bool ready;

  /// When set, the pull call with this 1-based index throws a transport error
  /// (used to simulate a partial download after earlier batches committed).
  final int failOnPullCall;
  int pullCalls = 0;
  final List<String> pushedUserIds = <String>[];
  final List<String> pushedEntities = <String>[];

  @override
  String get name => 'fake';

  @override
  bool get isReady => ready;

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    pushedUserIds.add(event.userId);
    pushedEntities.add(event.entity);
    return const SyncPushResult(applied: true);
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    pullCalls++;
    if (failOnPullCall == pullCalls) {
      throw const SyncTransportException('network_dropped_mid_download');
    }
    final List<SyncChange> filtered = changes
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
  String userId = 'user-1',
}) {
  return SyncChange(
    cursorId: cursorId,
    cloudTable: 'weight_logs',
    recordId: recordId,
    operation: SyncOperation.create,
    payload: <String, Object?>{
      'id': recordId,
      'user_id': userId,
      'weight_kg': 82.5,
      'logged_at': '2026-01-01T06:00:00Z',
      'created_at': '2026-01-01T06:00:00Z',
      'updated_at': '2026-01-01T06:00:00Z',
      'row_version': 1,
    },
  );
}

List<SyncChange> _manyWeightChanges(
  int count, {
  String userId = 'user-1',
}) {
  return <SyncChange>[
    for (int i = 1; i <= count; i++)
      _weightChange(i, recordId: 'wl-$i', userId: userId),
  ];
}

SyncChange _profileChange(
  int cursorId, {
  String userId = 'user-1',
}) {
  return SyncChange(
    cursorId: cursorId,
    cloudTable: 'profiles',
    recordId: userId,
    operation: SyncOperation.update,
    payload: <String, Object?>{
      'id': userId,
      'display_name': 'Test User',
      'avatar_url': null,
      'height_cm': 180.0,
      'weight_kg': 84.0,
      'birth_date': '1993-07-14',
      'fitness_goal': 'weightLoss',
      'activity_level': 'moderate',
      'created_at': '2026-01-01T06:00:00Z',
      'updated_at': '2026-01-02T06:00:00Z',
      'row_version': 29,
    },
  );
}

SyncChange _unsupportedChange(
  int cursorId, {
  String userId = 'user-1',
}) {
  return SyncChange(
    cursorId: cursorId,
    cloudTable: 'user_achievements',
    recordId: 'ach-1',
    operation: SyncOperation.create,
    payload: <String, Object?>{
      'id': 'ach-1',
      'user_id': userId,
      'achievement_id': 'ach-def-1',
      'created_at': '2026-01-01T06:00:00Z',
      'updated_at': '2026-01-01T06:00:00Z',
      'row_version': 1,
    },
  );
}

Future<Database> _insertUser(
  AppDatabase appDatabase,
  String id,
) async {
  final Database db = await appDatabase.database;
  await db.insert('users', <String, Object?>{
    'id': id,
    'name': id,
    'email': '$id@x.com',
    'provider': 'email',
  });
  return db;
}

Future<void> _insertWeightRow(
  Database db, {
  required int id,
  required String userId,
  required String uuid,
  int rowVersion = 1,
}) async {
  await db.insert('weight_log', <String, Object?>{
    'id': id,
    'uuid': uuid,
    'user_id': userId,
    'weight_kg': 80.0,
    'logged_at': 1767225600000,
    'created_at': 1767225600000,
    'updated_at': 1767225600000,
    'row_version': rowVersion,
  });
}

Future<void> _insertFoodItem(
  Database db, {
  required int id,
  required String? userId,
  required String uuid,
  required int isCustom,
}) async {
  await db.insert('food_item', <String, Object?>{
    'id': id,
    'uuid': uuid,
    'user_id': userId,
    'name': 'food-$id',
    'is_custom': isCustom,
    'created_at': 1767225600000,
    'updated_at': 1767225600000,
    'row_version': 1,
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ownership analyzer', () {
    late AppDatabase appDatabase;
    late LocalDataOwnershipAnalyzer analyzer;

    setUp(() async {
      await databaseFactory.deleteDatabase(await _databasePath());
      appDatabase = AppDatabase();
      await appDatabase.database;
      // Orphan rows carry an empty user_id, which is a legal pre-sync state in
      // this app but violates the users FK; disable enforcement for analysis.
      final Database db = await appDatabase.database;
      await db.execute('PRAGMA foreign_keys = OFF');
      analyzer = LocalDataOwnershipAnalyzer(database: appDatabase);
      SyncEventRecorder.configure(
        repository: SyncEventRepositoryImpl(
          SyncEventLocalDataSource(database: appDatabase),
        ),
        activeUserId: 'user-1',
      );
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('a clean database reports an empty analysis', () async {
      await _insertUser(appDatabase, 'user-1');
      final OwnershipAnalysis analysis = await analyzer.analyze('user-1');
      expect(analysis.isEmpty, isTrue);
      expect(analysis.orphanRows, 0);
      expect(analysis.foreignRows, 0);
      expect(analysis.previousAccountIds, isEmpty);
    });

    test('orphan rows (no owner) are detected but never auto-adopted',
        () async {
      final Database db = await _insertUser(appDatabase, 'user-1');
      await _insertWeightRow(db, id: 1, userId: '', uuid: 'wl-orphan');

      final OwnershipAnalysis analysis = await analyzer.analyze('user-1');
      expect(analysis.hasOrphans, isTrue);
      expect(analysis.orphanRows, 1);
      expect(analysis.byTable['weight_log']!.orphans, 1);
      expect(analysis.foreignRows, 0);

      // Still there afterwards: analysis never mutates data.
      final List<Map<String, Object?>> rows =
          await db.query('weight_log');
      expect(rows.single['user_id'], '');
    });

    test('rows owned by another account are reported as foreign', () async {
      final Database db = await _insertUser(appDatabase, 'user-1');
      await _insertUser(appDatabase, 'old-user');
      await _insertWeightRow(
        db,
        id: 1,
        userId: 'old-user',
        uuid: 'wl-old',
      );

      final OwnershipAnalysis analysis = await analyzer.analyze('user-1');
      expect(analysis.hasForeignData, isTrue);
      expect(analysis.foreignRows, 1);
      expect(analysis.previousAccountIds, {'old-user'});
      expect(analysis.singlePreviousAccountId, 'old-user');
    });

    test('master-hybrid rows (NULL user_id) are never counted as orphans',
        () async {
      final Database db = await appDatabase.database;
      // food_item master catalog row: is_custom = 0, no owner.
      await _insertFoodItem(db, id: 1, userId: null, uuid: 'fi-master', isCustom: 0);
      // fitness_goal seeded template: user_id NULL. The app seeds templates
      // with small ids, so use an id that cannot collide.
      await db.insert('fitness_goal', <String, Object?>{
        'id': 101,
        'uuid': 'fg-master',
        'user_id': null,
        'title': 'Build Muscle',
        'goal_type': 'muscle_gain',
        'current_value': 0,
        'status': 'active',
        'created_at': 1767225600000,
        'updated_at': 1767225600000,
        'row_version': 1,
      });
      // exercise master row: user_id NULL.
      await db.insert('exercise', <String, Object?>{
        'id': 1,
        'uuid': 'ex-master',
        'user_id': null,
        'name': 'Push Up',
        'is_custom': 0,
        'created_at': 1767225600000,
        'updated_at': 1767225600000,
        'row_version': 1,
      });

      final OwnershipAnalysis analysis = await analyzer.analyze('user-1');
      expect(analysis.isEmpty, isTrue,
          reason: 'master catalog rows are exempt from ownership');
    });

    test('a custom food_item orphan is adoptable, master rows are not',
        () async {
      final Database db = await _insertUser(appDatabase, 'user-1');
      await _insertFoodItem(db, id: 1, userId: null, uuid: 'fi-master', isCustom: 0);
      await _insertFoodItem(db, id: 2, userId: '', uuid: 'fi-custom', isCustom: 1);

      final OwnershipAnalysis analysis = await analyzer.analyze('user-1');
      expect(analysis.orphanRows, 1);
      expect(analysis.byTable['food_item']!.orphans, 1);

      final LocalDataAdoptionResult adoption =
          await analyzer.adoptOrphans(userId: 'user-1');
      expect(adoption.adoptedRows, 1);

      // Master row untouched; custom row adopted.
      final List<Map<String, Object?>> rows = await db.query(
        'food_item',
        orderBy: 'id',
      );
      expect(rows[0]['user_id'], isNull);
      expect(rows[1]['user_id'], 'user-1');
      expect(rows[1]['row_version'], 2);
      expect(rows[1]['uuid'], isNotNull);
    });

    test('adoption reassigns orphans, stamps sync columns and enqueues creates',
        () async {
      final Database db = await _insertUser(appDatabase, 'user-1');
      await _insertWeightRow(db, id: 1, userId: '', uuid: 'wl-orphan');

      final LocalDataAdoptionResult adoption =
          await analyzer.adoptOrphans(userId: 'user-1');
      expect(adoption.adoptedRows, 1);
      expect(adoption.byTable['weight_log'], 1);

      final List<Map<String, Object?>> rows =
          await db.query('weight_log');
      expect(rows.single['user_id'], 'user-1');
      expect(rows.single['row_version'], 2);
      expect(rows.single['uuid'], isNotEmpty);

      // A CREATE outbox event was enqueued atomically for the adopted row.
      final SyncEventRepositoryImpl eventRepo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      final List<SyncEvent> pending =
          await eventRepo.getPendingByUserId('user-1');
      expect(pending, hasLength(1));
      expect(pending.single.entity, 'weight_log');
      expect(pending.single.operation, SyncOperation.create);
    });

    test('adoption never touches foreign rows', () async {
      final Database db = await _insertUser(appDatabase, 'user-1');
      await _insertUser(appDatabase, 'old-user');
      await _insertWeightRow(db, id: 1, userId: 'old-user', uuid: 'wl-old');
      await _insertWeightRow(db, id: 2, userId: '', uuid: 'wl-orphan');

      final LocalDataAdoptionResult adoption =
          await analyzer.adoptOrphans(userId: 'user-1');
      expect(adoption.adoptedRows, 1);

      final List<Map<String, Object?>> rows =
          await db.query('weight_log', orderBy: 'id');
      expect(rows[0]['user_id'], 'old-user');
      expect(rows[0]['row_version'], 1);
      expect(rows[1]['user_id'], 'user-1');
    });
  });

  group('initial sync service', () {
    late AppDatabase appDatabase;
    late SyncEngine engine;
    late SyncStateRepositoryImpl stateRepo;
    late RemoteChangeApplier applier;
    late LocalDataOwnershipAnalyzer analyzer;

    setUp(() async {
      await databaseFactory.deleteDatabase(await _databasePath());
      appDatabase = AppDatabase();
      await appDatabase.database;
      final Database db = await appDatabase.database;
      await db.execute('PRAGMA foreign_keys = OFF');
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
      analyzer = LocalDataOwnershipAnalyzer(database: appDatabase);
    });

    tearDown(() async {
      await appDatabase.close();
    });

    InitialSyncService buildService(SyncTransport transport) {
      return InitialSyncService(
        database: appDatabase,
        engine: engine,
        transport: transport,
        applier: applier,
        ownershipAnalyzer: analyzer,
        syncStateRepository: stateRepo,
      );
    }

    test('new user, empty DB: pulls cloud rows, pushes own records, completes',
        () async {
      await _insertUser(appDatabase, 'user-1');
      // Local mutation queued while offline before first sync.
      await engine.track(
        userId: 'user-1',
        entity: 'weight_log',
        entityId: 'wl-9',
        operation: SyncOperation.create,
      );
      final _FakePullTransport transport = _FakePullTransport(
        changes: <SyncChange>[
          _weightChange(1, recordId: 'wl-1'),
          _weightChange(2, recordId: 'wl-2'),
        ],
      );

      final InitialSyncResult result = await buildService(transport).run(
        userId: 'user-1',
        ensureProfile: (_) async {},
      );

      expect(result.phase, InitialSyncPhase.complete);
      expect(result.success, isTrue);
      expect(result.alreadyComplete, isFalse);
      expect(result.changesPulled, 2);
      expect(result.eventsPushed, 1, reason: 'local pending record pushed');
      expect(transport.pushedUserIds, contains('user-1'));

      final SyncState? state = await stateRepo.getByUserId('user-1');
      expect(state, isNotNull);
      expect(state!.cursor, 2);
      expect(state.initialSyncCompleted, isTrue);

      final Database db = await appDatabase.database;
      expect(await db.query('weight_log'), hasLength(2));
      expect(result.analysis, isNotNull);
    });

    test('existing user whose initial sync already completed: no re-pull',
        () async {
      await _insertUser(appDatabase, 'user-1');
      await stateRepo.upsert(SyncState(
        userId: 'user-1',
        cursor: 5,
        initialSyncCompleted: true,
        lastSyncAt: DateTime.now(),
        status: 'success',
        updatedAt: DateTime.now(),
      ));
      final _FakePullTransport transport = _FakePullTransport(
        changes: _manyWeightChanges(5),
      );

      final InitialSyncResult result = await buildService(transport).run(
        userId: 'user-1',
        ensureProfile: (_) async {},
      );

      expect(result.alreadyComplete, isTrue);
      expect(result.phase, InitialSyncPhase.complete);
      expect(transport.pullCalls, 0, reason: 'no pull on already-complete');
    });

    test('existing local data is preserved and never silently uploaded',
        () async {
      await _insertUser(appDatabase, 'user-1');
      await _insertUser(appDatabase, 'old-user');
      final Database db = await appDatabase.database;
      // Local rows from before sign-in: an orphan, a foreign account row and
      // a current-account row.
      await _insertWeightRow(db, id: 1, userId: '', uuid: 'wl-orphan');
      await _insertWeightRow(db, id: 2, userId: 'old-user', uuid: 'wl-old');
      await _insertWeightRow(db, id: 3, userId: 'user-1', uuid: 'wl-mine');
      // The previous account has its own pending events.
      await engine.track(
        userId: 'old-user',
        entity: 'weight_log',
        entityId: 'wl-old-pending',
        operation: SyncOperation.create,
      );

      final _FakePullTransport transport = _FakePullTransport(
        changes: <SyncChange>[
          _weightChange(1, recordId: 'wl-1'),
        ],
      );

      final InitialSyncResult result = await buildService(transport).run(
        userId: 'user-1',
        ensureProfile: (_) async {},
      );

      expect(result.success, isTrue);
      // The 3 pre-sync rows are preserved with their original owners (the
      // pulled cloud row brings the total to 4); nothing was deleted and no
      // silent adoption ran.
      expect(
        await db.query('weight_log', where: "user_id = ''"),
        hasLength(1),
        reason: 'orphan row preserved, not auto-adopted',
      );
      expect(
        await db.query('weight_log', where: "user_id = 'old-user'"),
        hasLength(1),
        reason: 'foreign account row preserved',
      );
      expect(
        await db.query('weight_log', where: "user_id = 'user-1'"),
        hasLength(2),
        reason: 'own row + the pulled cloud row',
      );
      expect(transport.pushedUserIds, isNot(contains('old-user')));

      // The analysis exposes the ownership situation for the UI.
      expect(result.analysis, isNotNull);
      expect(result.analysis!.orphanRows, 1);
      expect(result.analysis!.foreignRows, 1);
      expect(result.analysis!.previousAccountIds, {'old-user'});
    });

    test('offline: reports offline, touches nothing, can be retried', () async {
      await _insertUser(appDatabase, 'user-1');
      final Database db = await appDatabase.database;
      await _insertWeightRow(db, id: 1, userId: 'user-1', uuid: 'wl-1');

      final _FakePullTransport transport = _FakePullTransport(
        changes: _manyWeightChanges(5),
        ready: false,
      );

      final InitialSyncResult result = await buildService(transport).run(
        userId: 'user-1',
        ensureProfile: (_) async {},
      );

      expect(result.phase, InitialSyncPhase.offline);
      expect(transport.pullCalls, 0);
      expect(await stateRepo.getByUserId('user-1'), isNull,
          reason: 'never marked complete offline');
      expect(await db.query('weight_log'), hasLength(1),
          reason: 'local data untouched');

      // A later online run retries and completes.
      final InitialSyncResult retried = await buildService(
        _FakePullTransport(changes: _manyWeightChanges(5)),
      ).run(
        userId: 'user-1',
        ensureProfile: (_) async {},
      );
      expect(retried.phase, InitialSyncPhase.complete);
      expect((await stateRepo.getByUserId('user-1'))!.initialSyncCompleted,
          isTrue);
      expect(await db.query('weight_log'), hasLength(5));
    });

    test('partial download keeps prior data and cursor; retry completes',
        () async {
      await _insertUser(appDatabase, 'user-1');
      // 150 rows: batch 1 (1-100) commits, batch 2 throws mid-download.
      final _FakePullTransport failing = _FakePullTransport(
        changes: _manyWeightChanges(150),
        failOnPullCall: 2,
      );

      final InitialSyncResult failed = await buildService(failing).run(
        userId: 'user-1',
        ensureProfile: (_) async {},
      );

      expect(failed.phase, InitialSyncPhase.failed);
      expect(failed.error, isA<SyncTransportException>());
      final SyncState? state = await stateRepo.getByUserId('user-1');
      expect(state, isNotNull);
      expect(state!.cursor, 100, reason: 'committed batch kept its cursor');
      expect(state.initialSyncCompleted, isFalse);

      final Database db = await appDatabase.database;
      expect(await db.query('weight_log'), hasLength(100),
          reason: 'committed rows survive the failure');

      // Retry with a healthy transport pulls only the remaining rows.
      final InitialSyncResult retried = await buildService(
        _FakePullTransport(changes: _manyWeightChanges(150)),
      ).run(
        userId: 'user-1',
        ensureProfile: (_) async {},
      );
      expect(retried.phase, InitialSyncPhase.complete);
      expect(retried.changesPulled, 50);
      final SyncState? done = await stateRepo.getByUserId('user-1');
      expect(done!.cursor, 150);
      expect(done.initialSyncCompleted, isTrue);
      expect(await db.query('weight_log'), hasLength(150));
    });

    test('an unappliable change in the history does not stall the initial pull forever',
        () async {
      await _insertUser(appDatabase, 'user-1');
      final Database db = await appDatabase.database;
      await db.execute('PRAGMA foreign_keys = ON');
      // The server logs user-owned rows for tables the app has no local mapping
      // for (gamification/streak tables). A fresh install replays the whole
      // history from cursor 0, so one such row must not abort the pull and
      // freeze the cursor forever (the profile row would never land).
      final _FakePullTransport transport = _FakePullTransport(
        changes: <SyncChange>[
          _unsupportedChange(1),
          _weightChange(2, recordId: 'wl-1'),
          _profileChange(3),
        ],
      );

      final InitialSyncResult result = await buildService(transport).run(
        userId: 'user-1',
        ensureProfile: (_) async {},
      );

      expect(result.success, isTrue,
          reason: 'a single bad row must not block the whole history');
      expect(transport.pullCalls, 1);
      final SyncState? state = await stateRepo.getByUserId('user-1');
      expect(state, isNotNull);
      expect(state!.cursor, 3);
      expect(state.initialSyncCompleted, isTrue);
      expect(await db.query('weight_log'), hasLength(1));
      final List<Map<String, Object?>> profiles = await db.query('user_profile');
      expect(profiles, hasLength(1),
          reason: 'the profile change after the bad row must still be applied');
      expect(profiles.single['height_cm'], 180.0);
      expect(profiles.single['weight_kg'], 84.0);
      expect(profiles.single['birth_date'], DateTime.parse('1993-07-14').millisecondsSinceEpoch);
      expect(profiles.single['fitness_goal'], 'weightLoss');
    });

    test('progress is reported across the pull stages', () async {
      await _insertUser(appDatabase, 'user-1');
      final _FakePullTransport transport = _FakePullTransport(
        changes: _manyWeightChanges(3),
      );
      final List<InitialSyncProgress> progress = <InitialSyncProgress>[];

      await buildService(transport).run(
        userId: 'user-1',
        ensureProfile: (_) async {},
        onProgress: progress.add,
      );

      expect(progress, isNotEmpty);
      expect(progress.first.phase, InitialSyncPhase.syncing);
      expect(progress.last.phase, InitialSyncPhase.complete);
      expect(progress.map((p) => p.changesPulled), contains(3));
    });
  });

  group('per-user isolation on a shared device', () {
    late AppDatabase appDatabase;
    late SyncEngine engine;
    late SyncStateRepositoryImpl stateRepo;
    late RemoteChangeApplier applier;
    late InitialSyncService service;

    setUp(() async {
      await databaseFactory.deleteDatabase(await _databasePath());
      appDatabase = AppDatabase();
      await appDatabase.database;
      await _insertUser(appDatabase, 'user-1');
      await _insertUser(appDatabase, 'user-2');
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
      service = InitialSyncService(
        database: appDatabase,
        engine: engine,
        transport: _FakePullTransport(changes: const <SyncChange>[]),
        applier: applier,
        ownershipAnalyzer: LocalDataOwnershipAnalyzer(database: appDatabase),
        syncStateRepository: stateRepo,
      );
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('each user gets an independent cursor and data set', () async {
      await service.run(userId: 'user-1', ensureProfile: (_) async {});
      await service.run(userId: 'user-2', ensureProfile: (_) async {});

      final SyncState? one = await stateRepo.getByUserId('user-1');
      final SyncState? two = await stateRepo.getByUserId('user-2');
      expect(one!.initialSyncCompleted, isTrue);
      expect(two!.initialSyncCompleted, isTrue);
      expect(one.userId, isNot(two.userId));

      // Re-running user-1 is a no-op already-complete path.
      final InitialSyncResult again = await service.run(
        userId: 'user-1',
        ensureProfile: (_) async {},
      );
      expect(again.alreadyComplete, isTrue);
    });
  });
}
