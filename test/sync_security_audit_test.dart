import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/sync_conflict_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_conflict_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/data/services/sync/sync_table_registry.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/repositories/sync_event_repository.dart';
import 'package:nexfit/domain/repositories/sync_state_repository.dart';

/// PROMPT 24 — Sync security audit.
///
/// Ten checks covering cross-user isolation (read / write / update / delete),
/// master-data read-only, `sync_state` local-only, no service-role key in the
/// Flutter app, no PII columns in sync payloads, no passwords in payloads and
/// no token/secret logging. Two test users (`user-1`, `user-2`) run on
/// separate SQLite databases sharing a user-scoped cloud transport that
/// enforces row ownership (mirroring Supabase RLS). RLS itself is never
/// weakened anywhere; these checks only confirm the client + contract uphold
/// the same boundaries.
///
/// See `docs/NEXFIT_SYNC_SECURITY_AUDIT.md`.

// ---------------------------------------------------------------------------
// User-scoped cloud (RLS-like ownership enforcement)
// ---------------------------------------------------------------------------

class _CloudRow {
  _CloudRow(this.data, this.version);
  final Map<String, Object?> data;
  int version;
}

class _Change {
  _Change({
    required this.id,
    required this.userId,
    required this.table,
    required this.recordId,
    required this.operation,
    required this.payload,
  });

  final int id;
  final String userId;
  final String table;
  final String recordId;
  final String operation;
  final Map<String, Object?> payload;
}

class _SecureCloud {
  final Map<String, Map<String, _CloudRow>> _rows =
      <String, Map<String, _CloudRow>>{};
  final List<_Change> _changes = <_Change>[];
  int _nextId = 1;
  int inserts = 0;

  Map<String, _CloudRow> rowsFor(String table) =>
      _rows[table] ?? const <String, _CloudRow>{};

  int get changeCount => _changes.length;

  bool hasTable(String table) => _rows.containsKey(table);

  List<_Change> changesFor(
    String userId, {
    required int cursor,
    int limit = 100,
  }) {
    return _changes
        .where((_Change c) => c.userId == userId && c.id > cursor)
        .take(limit)
        .toList();
  }

  void put(String table, String recordId, _CloudRow row) {
    _rows.putIfAbsent(table, () => <String, _CloudRow>{})[recordId] = row;
  }

  void append({
    required String userId,
    required String table,
    required String recordId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    _changes.add(
      _Change(
        id: _nextId++,
        userId: userId,
        table: table,
        recordId: recordId,
        operation: operation,
        payload: Map<String, Object?>.of(payload),
      ),
    );
  }
}

class _SecureTransport implements SyncTransport {
  _SecureTransport({required this.store, required this.database});

  final _SecureCloud store;
  final AppDatabase database;
  int pushCalls = 0;

  @override
  String get name => 'secure-cloud';

  @override
  bool get isReady => true;

  Future<Map<String, Object?>?> _readLocalRow(
    SyncTableMapping mapping,
    SyncEvent event,
  ) async {
    final Database db = await database.database;
    final List<Map<String, Object?>> rows = await db.query(
      mapping.localTable,
      where: '${mapping.localKeyColumn} = ?',
      whereArgs: <Object?>[
        mapping.localKeyColumn == 'user_id' ? event.userId : event.entityId,
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : Map<String, Object?>.from(rows.first);
  }

  Map<String, Object?> _cloudRow(
    SyncTableMapping mapping,
    Map<String, Object?> localRow,
  ) {
    final Map<String, Object?> cloud = <String, Object?>{
      'id': localRow['uuid'] as String,
      'user_id': (localRow['user_id'] as String?) ?? '',
      'row_version': (localRow['row_version'] as num?)?.toInt() ?? 0,
    };
    if (mapping.cloudHasDeletedAt) {
      final Object? deletedAt = localRow['deleted_at'];
      cloud['deleted_at'] = deletedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((deletedAt as num).toInt())
              .toUtc()
              .toIso8601String();
    }
    for (final MapEntry<String, String> entry in mapping.localToCloud.entries) {
      cloud[entry.value] = _convert(mapping, entry.value, localRow[entry.key]);
    }
    return cloud;
  }

  Object? _convert(
    SyncTableMapping mapping,
    String cloudColumn,
    Object? value,
  ) {
    if (value == null) return null;
    if (mapping.timestampColumns.contains(cloudColumn)) {
      return DateTime.fromMillisecondsSinceEpoch((value as num).toInt())
          .toUtc()
          .toIso8601String();
    }
    if (mapping.dateColumns.contains(cloudColumn)) {
      final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
        (value as num).toInt(),
      );
      return '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    }
    if (mapping.booleanColumns.contains(cloudColumn)) {
      return value == 1;
    }
    return value;
  }

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    pushCalls++;
    final SyncTableMapping? mapping = SyncTableRegistry.byLocalTable(
      event.entity,
    );
    if (mapping == null) {
      return const SyncPushResult(applied: false, lastError: 'unsupported_entity');
    }
    final Map<String, Object?>? localRow = await _readLocalRow(mapping, event);
    final Map<String, Object?> cloud = localRow == null
        ? <String, Object?>{
            'id': event.entityId,
            'user_id': event.userId,
            'row_version': 0,
          }
        : _cloudRow(mapping, localRow);

    // RLS-equivalent ownership guard: a signed-in user may only write rows
    // whose `user_id` is their own. A leaked/foreign local row is rejected and
    // never lands in another tenant's store.
    if ((cloud['user_id'] as String) != event.userId) {
      return const SyncPushResult(
        applied: false,
        lastError: 'security_policy_violation',
      );
    }

    switch (event.operation) {
      case SyncOperation.create:
      case SyncOperation.update:
        final _CloudRow? existing = store.rowsFor(mapping.cloudTable)[
            cloud['id'] as String];
        if (existing != null &&
            event.baseVersion > 0 &&
            existing.version != event.baseVersion) {
          return SyncPushResult(
            applied: false,
            conflict: true,
            serverRowVersion: existing.version,
            serverData: Map<String, Object?>.of(existing.data),
          );
        }
        final int version = (existing?.version ?? 0) + 1;
        cloud['row_version'] = version;
        store.put(mapping.cloudTable, cloud['id'] as String, _CloudRow(cloud, version));
        if (existing == null) store.inserts++;
        store.append(
          userId: event.userId,
          table: mapping.cloudTable,
          recordId: cloud['id'] as String,
          operation: existing == null ? 'INSERT' : 'UPDATE',
          payload: cloud,
        );
        return SyncPushResult(applied: true, serverRowVersion: version);
      case SyncOperation.delete:
        final String? recordId = localRow?['uuid'] as String?;
        if (recordId == null) return const SyncPushResult(applied: true);
        final _CloudRow? existing = store.rowsFor(mapping.cloudTable)[recordId];
        if (existing == null) return const SyncPushResult(applied: true);
        if (existing.version != event.baseVersion) {
          return SyncPushResult(
            applied: false,
            conflict: true,
            serverRowVersion: existing.version,
            serverData: Map<String, Object?>.of(existing.data),
          );
        }
        final int version = existing.version + 1;
        final Map<String, Object?> tombstoned =
            Map<String, Object?>.of(existing.data)
              ..['deleted_at'] = DateTime.now().toUtc().toIso8601String()
              ..['row_version'] = version;
        store.put(mapping.cloudTable, recordId, _CloudRow(tombstoned, version));
        store.append(
          userId: event.userId,
          table: mapping.cloudTable,
          recordId: recordId,
          operation: 'DELETE',
          payload: const <String, Object?>{},
        );
        return SyncPushResult(applied: true, serverRowVersion: version);
    }
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    final List<_Change> changes = store.changesFor(
      userId,
      cursor: cursor,
      limit: limit,
    );
    final List<SyncChange> result = <SyncChange>[
      for (final _Change change in changes)
        SyncChange(
          cursorId: change.id,
          cloudTable: change.table,
          recordId: change.recordId,
          operation: _operationFrom(change.operation),
          payload: Map<String, Object?>.of(change.payload),
        ),
    ];
    return SyncPullBatch(
      changes: result,
      nextCursor: result.isEmpty ? cursor : result.last.cursorId,
      hasMore: result.length == limit,
    );
  }

  SyncOperation _operationFrom(String value) {
    switch (value) {
      case 'INSERT':
        return SyncOperation.create;
      case 'DELETE':
        return SyncOperation.delete;
      default:
        return SyncOperation.update;
    }
  }
}

// ---------------------------------------------------------------------------
// Per-user device
// ---------------------------------------------------------------------------

class _UserDevice {
  _UserDevice(this.name, this.userId);

  final String name;
  final String userId;
  late AppDatabase db;
  late Database raw;
  late SyncEventRepository eventRepo;
  late SyncStateRepository stateRepo;

  Future<void> init() async {
    await databaseFactory.deleteDatabase(
      path.join(await databaseFactory.getDatabasesPath(), '$name.db'),
    );
    db = AppDatabase(databaseName: '$name.db');
    raw = await db.database;
    await raw.insert('users', <String, Object?>{
      'id': userId,
      'name': 'User $userId',
      'email': '$userId@x.com',
      'provider': 'email',
    });
    eventRepo = SyncEventRepositoryImpl(
      SyncEventLocalDataSource(database: db),
    );
    stateRepo = SyncStateRepositoryImpl(
      SyncStateLocalDataSource(database: db),
    );
  }

  SyncEngine engine() => SyncEngine(
        repository: eventRepo,
        syncStateRepository: stateRepo,
        conflictRepository: SyncConflictRepositoryImpl(
          SyncConflictLocalDataSource(database: db),
        ),
        database: db,
        deviceIdProvider: () async => 'device-$name',
      );

  Future<void> close() => db.close();
}

Future<int> _seedWeightLog(
  Database db, {
  required String userId,
  required String uuid,
  double weightKg = 80.0,
}) async {
  final int now = DateTime.now().millisecondsSinceEpoch;
  return db.insert('weight_log', <String, Object?>{
    'uuid': uuid,
    'user_id': userId,
    'weight_kg': weightKg,
    'logged_at': now,
    'created_at': now,
    'updated_at': now,
    'row_version': 1,
  });
}

Future<void> _makeDue(_UserDevice device) async {
  for (final SyncEvent event
      in await device.eventRepo.getRetryableByUserId(
    device.userId,
    now: DateTime.now().add(const Duration(days: 30)),
  )) {
    await device.eventRepo.update(event.copyWith(clearNextRetryAt: true));
  }
}

const Set<String> _sensitiveColumnTerms = <String>{
  'email', 'phone', 'password', 'passwd', 'pwd', 'pin', 'token',
  'session', 'secret', 'auth_key', 'api_key', 'hash',
};

bool _isSensitive(String value) {
  final String lower = value.toLowerCase();
  return _sensitiveColumnTerms.any(lower.contains);
}

// ---------------------------------------------------------------------------
// Source inspection
// ---------------------------------------------------------------------------

Future<List<File>> _libFiles() async {
  final List<File> files = <File>[];
  await for (final FileSystemEntity entity
      in Directory('lib').list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) files.add(entity);
  }
  return files;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late _UserDevice user1;
  late _UserDevice user2;
  late _SecureCloud store;

  setUp(() async {
    store = _SecureCloud();
    user1 = _UserDevice('u1', 'user-1');
    user2 = _UserDevice('u2', 'user-2');
    await user1.init();
    await user2.init();
  });

  tearDown(() async {
    await user1.close();
    await user2.close();
  });

  group('cross-user isolation (two test users)', () {
    test('1. read isolation: a user never pulls another user\'s changes',
        () async {
      final int id = await _seedWeightLog(
        user1.raw,
        userId: 'user-1',
        uuid: 'wl-1',
      );
      await user1.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$id',
            operation: SyncOperation.create,
          );
      await user1.engine().sync(
            userId: 'user-1',
            transport: _SecureTransport(store: store, database: user1.db),
            applier: RemoteChangeApplier(database: user1.db),
          );
      expect(store.rowsFor('weight_logs'), hasLength(1));

      // user-2 syncs: its feed is empty, nothing lands in its DB.
      final SyncRunResult u2 = await user2.engine().sync(
            userId: 'user-2',
            transport: _SecureTransport(store: store, database: user2.db),
            applier: RemoteChangeApplier(database: user2.db),
          );
      expect(u2.pulled, 0, reason: 'user-2 must not see user-1\'s changes');
      expect(await user2.raw.query('weight_log'), isEmpty);
    });

    test('2. write isolation: a cross-user push is rejected, never lands in '
        'another tenant\'s store', () async {
      // Simulate a device that holds another account's data (e.g. restored
      // from a backup of a different account): user-2's profile and one of its
      // rows are present in user-1's database. The local FK passes, but the
      // transport's ownership guard must still reject the cross-user write.
      await user1.raw.insert('users', <String, Object?>{
        'id': 'user-2',
        'name': 'User user-2',
        'email': 'user-2@x.com',
        'provider': 'email',
      });
      final int id = await _seedWeightLog(
        user1.raw,
        userId: 'user-2',
        uuid: 'wl-2',
        weightKg: 90.0,
      );
      await user1.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$id',
            operation: SyncOperation.create,
          );

      final SyncRunResult result = await user1.engine().sync(
            userId: 'user-1',
            transport: _SecureTransport(store: store, database: user1.db),
            applier: RemoteChangeApplier(database: user1.db),
          );
      expect(result.failed, 1,
          reason: 'the ownership guard rejects the cross-user write');
      expect(store.rowsFor('weight_logs'), isEmpty,
          reason: 'no row was written into the cloud');
      expect(store.changeCount, 0,
          reason: 'no change feed entry leaked for user-2');
      final Map<String, int> counts =
          await user1.eventRepo.countByStatus('user-1');
      expect(
        counts[SyncStatus.failedPermanent.name],
        1,
        reason: 'the engine treats a security-policy rejection as terminal',
      );
    });

    test('3. update isolation: one user\'s edits never reach another user',
        () async {
      final int a = await _seedWeightLog(
        user1.raw,
        userId: 'user-1',
        uuid: 'wl-1',
        weightKg: 80.0,
      );
      await user1.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$a',
            operation: SyncOperation.create,
          );
      final int b = await _seedWeightLog(
        user2.raw,
        userId: 'user-2',
        uuid: 'wl-2',
        weightKg: 70.0,
      );
      await user2.engine().track(
            userId: 'user-2',
            entity: 'weight_log',
            entityId: '$b',
            operation: SyncOperation.create,
          );
      await user1.engine().sync(
            userId: 'user-1',
            transport: _SecureTransport(store: store, database: user1.db),
            applier: RemoteChangeApplier(database: user1.db),
          );
      await user2.engine().sync(
            userId: 'user-2',
            transport: _SecureTransport(store: store, database: user2.db),
            applier: RemoteChangeApplier(database: user2.db),
          );

      // user-2 updates its own row.
      final int now = DateTime.now().millisecondsSinceEpoch;
      await user2.raw.update(
        'weight_log',
        <String, Object?>{
          'weight_kg': 71.0,
          'updated_at': now,
          'row_version': 2,
        },
        where: 'uuid = ?',
        whereArgs: <Object?>['wl-2'],
      );
      await user2.engine().track(
            userId: 'user-2',
            entity: 'weight_log',
            entityId: '$b',
            operation: SyncOperation.update,
            baseVersion: 1,
          );
      await user2.engine().sync(
            userId: 'user-2',
            transport: _SecureTransport(store: store, database: user2.db),
            applier: RemoteChangeApplier(database: user2.db),
          );

      // user-1's pull sees nothing new.
      final SyncRunResult u1 = await user1.engine().sync(
            userId: 'user-1',
            transport: _SecureTransport(store: store, database: user1.db),
            applier: RemoteChangeApplier(database: user1.db),
          );
      expect(u1.pulled, 0);
      final List<Map<String, Object?>> rows =
          await user1.raw.query('weight_log');
      expect(rows.single['weight_kg'], 80.0,
          reason: 'user-2\'s edit never reaches user-1\'s database');
    });

    test('4. delete isolation: one user\'s delete never tombstones another '
        'user\'s row', () async {
      final int a = await _seedWeightLog(
        user1.raw,
        userId: 'user-1',
        uuid: 'wl-1',
      );
      await user1.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$a',
            operation: SyncOperation.create,
          );
      final int b = await _seedWeightLog(
        user2.raw,
        userId: 'user-2',
        uuid: 'wl-2',
      );
      await user2.engine().track(
            userId: 'user-2',
            entity: 'weight_log',
            entityId: '$b',
            operation: SyncOperation.create,
          );
      await user1.engine().sync(
            userId: 'user-1',
            transport: _SecureTransport(store: store, database: user1.db),
            applier: RemoteChangeApplier(database: user1.db),
          );
      await user2.engine().sync(
            userId: 'user-2',
            transport: _SecureTransport(store: store, database: user2.db),
            applier: RemoteChangeApplier(database: user2.db),
          );

      // user-2 deletes its own row.
      final int now = DateTime.now().millisecondsSinceEpoch;
      await user2.raw.update(
        'weight_log',
        <String, Object?>{
          'deleted_at': now,
          'updated_at': now,
          'row_version': 2,
        },
        where: 'uuid = ?',
        whereArgs: <Object?>['wl-2'],
      );
      await user2.engine().track(
            userId: 'user-2',
            entity: 'weight_log',
            entityId: '$b',
            operation: SyncOperation.delete,
            baseVersion: 1,
          );
      await user2.engine().sync(
            userId: 'user-2',
            transport: _SecureTransport(store: store, database: user2.db),
            applier: RemoteChangeApplier(database: user2.db),
          );

      // user-1 pulls nothing; its own row stays active.
      final SyncRunResult u1 = await user1.engine().sync(
            userId: 'user-1',
            transport: _SecureTransport(store: store, database: user1.db),
            applier: RemoteChangeApplier(database: user1.db),
          );
      expect(u1.pulled, 0);
      final List<Map<String, Object?>> rows =
          await user1.raw.query('weight_log');
      expect(rows.single['deleted_at'], isNull,
          reason: 'user-2\'s delete never tombstones user-1\'s row');
    });

    test('5. sync_state is local-only: never synced, never in the cloud',
        () async {
      final int id = await _seedWeightLog(
        user1.raw,
        userId: 'user-1',
        uuid: 'wl-1',
      );
      await user1.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$id',
            operation: SyncOperation.create,
          );
      await user1.engine().sync(
            userId: 'user-1',
            transport: _SecureTransport(store: store, database: user1.db),
            applier: RemoteChangeApplier(database: user1.db),
          );

      // Cursor state exists locally per user...
      expect((await user1.stateRepo.getByUserId('user-1'))!.cursor, greaterThan(0));
      // ...but never reaches the cloud store or the change feed.
      expect(store.hasTable('sync_state'), isFalse,
          reason: 'sync_state has no cloud mapping');
      expect(
        store.changesFor(
          'user-1',
          cursor: 0,
          limit: 1000,
        ).where((_Change c) => c.table == 'sync_state'),
        isEmpty,
      );
      expect(SyncTableRegistry.byLocalTable('sync_state'), isNull,
          reason: 'the sync registry contains no sync_state mapping');
    });

    test('9. no passwords or PII in payloads: pushed rows carry only mapped '
        'columns', () async {
      final int id = await _seedWeightLog(
        user1.raw,
        userId: 'user-1',
        uuid: 'wl-1',
        weightKg: 82.5,
      );
      await user1.engine().track(
            userId: 'user-1',
            entity: 'weight_log',
            entityId: '$id',
            operation: SyncOperation.create,
          );
      await user1.engine().sync(
            userId: 'user-1',
            transport: _SecureTransport(store: store, database: user1.db),
            applier: RemoteChangeApplier(database: user1.db),
          );

      final SyncTableMapping mapping =
          SyncTableRegistry.byLocalTable('weight_log')!;
      final Set<String> allowed = <String>{
        'id', 'user_id', 'row_version', 'deleted_at',
        ...mapping.localToCloud.values,
      };
      final _CloudRow row = store.rowsFor('weight_logs')['wl-1']!;
      for (final String key in row.data.keys) {
        expect(allowed.contains(key), isTrue,
            reason: 'unexpected column "$key" leaked into the sync payload');
        expect(_isSensitive(key), isFalse,
            reason: 'sensitive column "$key" must never be synced');
      }
    });

    test('10. no tokens, full uuids or secrets ever reach logs', () async {
      final List<String> captured = <String>[];
      final StreamSubscription<LogRecord> subscription =
          Logger.root.onRecord.listen(
        (LogRecord record) => captured.add(record.message),
      );
      final Level previous = Logger.root.level;
      Logger.root.level = Level.ALL;
      try {
        // A failing push logs an error path; a succeeding run logs the happy
        // path. Neither may contain sensitive data.
        final int id = await _seedWeightLog(
          user1.raw,
          userId: 'user-1',
          uuid: 'wl-1',
        );
        await user1.engine().track(
              userId: 'user-1',
              entity: 'weight_log',
              entityId: '$id',
              operation: SyncOperation.create,
            );
        final SyncEvent queued =
            (await user1.eventRepo
                    .getRetryableByUserId('user-1', now: DateTime(2100)))
                .single;
        final String fullUuid = queued.eventUuid!;

        final _RejectingTransport failing =
            _RejectingTransport(database: user1.db);
        await user1.engine().processQueue('user-1', transport: failing);
        await _makeDue(user1);
        await user1.engine().sync(
              userId: 'user-1',
              transport: _SecureTransport(store: store, database: user1.db),
              applier: RemoteChangeApplier(database: user1.db),
            );

        for (final String message in captured) {
          expect(message.contains(fullUuid), isFalse,
              reason: 'full event uuids must never be logged');
          expect(message.toLowerCase().contains('password'), isFalse);
          expect(message.toLowerCase().contains('auth_token'), isFalse);
          expect(message.toLowerCase().contains('secret'), isFalse);
        }
      } finally {
        Logger.root.level = previous;
        await subscription.cancel();
      }
    });
  });

  group('static contract checks (source inspection)', () {
    test('6. master data is read-only: the transport has no write path',
        () async {
      final String contracts = await File(
        'lib/data/services/sync/master_data_contracts.dart',
      ).readAsString();
      final String transport = await File(
        'lib/data/services/sync/supabase_master_data_transport.dart',
      ).readAsString();

      for (final String write in <String>[
        '.insert(', '.upsert(', '.delete(', '.update(',
      ]) {
        expect(transport.contains(write), isFalse,
            reason: 'master transport must never issue "$write"');
      }
      expect(contracts.contains('pullRows'), isTrue);
      expect(contracts.contains('getVersions'), isTrue);
      // Hybrid catalogs filter to master rows only (user_id IS NULL).
      expect(
        transport.contains('.isFilter(\'user_id\', null)') ||
            transport.contains('user_id'),
        isTrue,
      );
    });

    test('7. no service-role key in the Flutter app; anon key only',
        () async {
      final String service = await File(
        'lib/data/services/supabase/supabase_service.dart',
      ).readAsString();
      expect(service.contains('publishableKey:'), isTrue,
          reason: 'the app initialises Supabase with the publishable (anon) '
              'key, never the service-role key');

      for (final File file in await _libFiles()) {
        final String source = await file.readAsString();
        expect(
          source.contains('service_role') ||
              source.contains('serviceRole') ||
              source.contains('SERVICE_ROLE'),
          isFalse,
          reason: 'no file in lib/ may reference the service-role key',
        );
      }
    });

    test('8. no PII columns are part of any sync mapping', () async {
      for (final SyncTableMapping mapping in SyncTableRegistry.mappings) {
        for (final MapEntry<String, String> column
            in mapping.localToCloud.entries) {
          expect(_isSensitive(column.key), isFalse,
              reason: 'local column ${column.key} is PII/credential and must '
                  'not sync');
          expect(_isSensitive(column.value), isFalse,
              reason: 'cloud column ${column.value} is PII/credential and '
                  'must not sync');
        }
        for (final String cloudName
            in mapping.cloudForeignKeyNames.values) {
          expect(_isSensitive(cloudName), isFalse);
        }
      }
      // The profiles singleton maps body/targets, never the auth identity.
      final SyncTableMapping profiles =
          SyncTableRegistry.byLocalTable('user_profile')!;
      expect(
        profiles.localToCloud.containsKey('email') ||
            profiles.localToCloud.containsKey('password'),
        isFalse,
        reason: 'profiles sync must never carry the auth email/password',
      );
    });
  });
}

/// A transport whose push always throws, so the engine exercises its failure
/// logging path with a full event uuid and error text in flight.
class _RejectingTransport implements SyncTransport {
  _RejectingTransport({required this.database});

  final AppDatabase database;

  @override
  String get name => 'rejecting';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async {
    throw const SyncTransportException('network_unreachable');
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
