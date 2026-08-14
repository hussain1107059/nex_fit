import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/master_catalog_state_local_data_source.dart';
import 'package:nexfit/data/services/sync/master_data_contracts.dart';
import 'package:nexfit/data/services/sync/master_data_sync_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 16 — Master Data Synchronization tests.
///
/// Covers: fresh-install full download, existing-install skip (version
/// unchanged), version-changed incremental pull, partial download, network
/// failure, large multi-batch catalogs, duplicate rows, natural-key adoption
/// (seeded rows keep their ids while acquiring the cloud uuid), FK resolution
/// across catalogs, hybrid isolation (user rows never touched) and offline
/// behaviour.

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

int _msOf(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return DateTime.parse(value.toString()).toUtc().millisecondsSinceEpoch;
}

/// Scripted [MasterDataTransport] backing a single catalog's rows with a
/// version list. Every pull page is `limit`-sized with authoritative `hasMore`,
/// and failures can be injected at the version or a specific pull index.
class _FakeMasterTransport implements MasterDataTransport {
  _FakeMasterTransport({this.ready = true});

  final bool ready;
  final List<MasterCatalogVersion> versions = <MasterCatalogVersion>[];
  final Map<String, List<Map<String, Object?>>> rows =
      <String, List<Map<String, Object?>>>{};

  int versionCalls = 0;
  int pullCalls = 0;
  DateTime? lastSince;

  bool failVersions = false;
  int failOnPullIndex = -1;

  @override
  String get name => 'fake';

  @override
  bool get isReady => ready;

  void addVersion(String catalog, int dataVersion, {String? updatedAt}) {
    versions.add(
      MasterCatalogVersion(
        catalog: catalog,
        dataVersion: dataVersion,
        schemaVersion: 1,
        updatedAt: updatedAt == null
            ? null
            : DateTime.parse(updatedAt).toUtc(),
      ),
    );
  }

  void addRow(String catalog, Map<String, Object?> row) {
    rows.putIfAbsent(catalog, () => <Map<String, Object?>>[]).add(row);
  }

  @override
  Future<List<MasterCatalogVersion>> getVersions() async {
    versionCalls++;
    if (failVersions) {
      throw const MasterDataTransportException('network_down');
    }
    return List<MasterCatalogVersion>.of(versions);
  }

  @override
  Future<MasterCatalogPage> pullRows(
    String catalog, {
    DateTime? since,
    int offset = 0,
    int limit = 100,
  }) async {
    pullCalls++;
    lastSince = since;
    if (pullCalls == failOnPullIndex) {
      throw const MasterDataTransportException('partial_failure');
    }
    final List<Map<String, Object?>> all = rows[catalog] ?? <Map<String, Object?>>[];
    final int? sinceMs = since?.toUtc().millisecondsSinceEpoch;
    final List<Map<String, Object?>> filtered = all
        .where((Map<String, Object?> row) {
          if (sinceMs == null) return true;
          return _msOf(row['updated_at']) >= sinceMs;
        })
        .toList();
    if (offset >= filtered.length) {
      return const MasterCatalogPage(rows: <Map<String, Object?>>[], hasMore: false);
    }
    final int end = math.min(offset + limit, filtered.length);
    final List<Map<String, Object?>> page = filtered.sublist(offset, end);
    return MasterCatalogPage(
      rows: page,
      hasMore: end < filtered.length,
    );
  }
}

Map<String, Object?> _categoryRow({
  required String id,
  required String name,
  required String slug,
  String updatedAt = '2026-01-01T08:00:00Z',
  int sortOrder = 1,
}) {
  return <String, Object?>{
    'id': id,
    'name': name,
    'slug': slug,
    'description': null,
    'icon': slug,
    'color': 4279148398,
    'sort_order': sortOrder,
    'created_at': '2026-01-01T07:00:00Z',
    'updated_at': updatedAt,
    'deleted_at': null,
    'row_version': 1,
  };
}

Map<String, Object?> _foodRow({
  required String id,
  required String name,
  String updatedAt = '2026-01-01T08:00:00Z',
}) {
  return <String, Object?>{
    'id': id,
    'user_id': null,
    'name': name,
    'brand': null,
    'category': 'Grains',
    'serving_size': '100g',
    'serving_grams': 100.0,
    'calories': 130.0,
    'protein': 2.7,
    'carbs': 28.0,
    'fat': 0.3,
    'fiber': 1.0,
    'sugar': 0.1,
    'sodium': 2.0,
    'potassium': 35.0,
    'calcium': 10.0,
    'iron': 0.8,
    'vitamin_a': 0.0,
    'vitamin_c': 0.0,
    'water_percentage': 12.0,
    'barcode': null,
    'image_url': 'assets/food/$id.png',
    'is_custom': false,
    'created_at': '2026-01-01T07:00:00Z',
    'updated_at': updatedAt,
    'deleted_at': null,
    'row_version': 1,
  };
}

Map<String, Object?> _exerciseRow({
  required String id,
  required String name,
  String updatedAt = '2026-01-01T08:00:00Z',
}) {
  return <String, Object?>{
    'id': id,
    'user_id': null,
    'name': name,
    'scientific_name': null,
    'description': 'desc',
    'instructions': 'do it',
    'body_part': 'Chest',
    'secondary_muscle': null,
    'equipment': 'bodyweight',
    'difficulty': 'beginner',
    'category': 'chest',
    'image_url': 'assets/exercise/$id.png',
    'gif_url': 'assets/exercise/$id.gif',
    'calories_per_minute': 5.0,
    'estimated_calories': 50.0,
    'duration_seconds': 30,
    'sets': 3,
    'reps': 12,
    'rest_seconds': 30,
    'tips': null,
    'common_mistakes': null,
    'safety_instructions': null,
    'is_custom': false,
    'created_at': '2026-01-01T07:00:00Z',
    'updated_at': updatedAt,
    'deleted_at': null,
    'row_version': 1,
  };
}

Map<String, Object?> _templateRow({
  required String id,
  required String name,
  required String categoryId,
  String updatedAt = '2026-01-01T08:00:00Z',
}) {
  return <String, Object?>{
    'id': id,
    'category_id': categoryId,
    'name': name,
    'description': null,
    'difficulty': 'beginner',
    'duration_minutes': 30,
    'calories_burn': 200.0,
    'created_at': '2026-01-01T07:00:00Z',
    'updated_at': updatedAt,
    'deleted_at': null,
    'row_version': 1,
  };
}

Map<String, Object?> _templateExerciseRow({
  required String id,
  required String templateId,
  required String exerciseId,
  String updatedAt = '2026-01-01T08:00:00Z',
}) {
  return <String, Object?>{
    'id': id,
    'template_id': templateId,
    'exercise_id': exerciseId,
    'sets': 3,
    'reps': 12,
    'duration_seconds': 0,
    'rest_seconds': 30,
    'sort_order': 0,
    'created_at': '2026-01-01T07:00:00Z',
    'updated_at': updatedAt,
    'deleted_at': null,
    'row_version': 1,
  };
}

Map<String, Object?> _achievementDefRow({
  required String id,
  required String achievementType,
  required String name,
  String updatedAt = '2026-01-01T08:00:00Z',
}) {
  return <String, Object?>{
    'id': id,
    'achievement_type': achievementType,
    'name': name,
    'description': 'desc',
    'icon': achievementType,
    'xp_reward': 50,
    'sort_order': 1,
    'created_at': '2026-01-01T07:00:00Z',
    'updated_at': updatedAt,
    'deleted_at': null,
    'row_version': 1,
  };
}

String _catalogForTable(String localTable) {
  return MasterCatalogRegistry.catalogs
      .firstWhere((MasterCatalogSpec s) => s.localTable == localTable)
      .catalog;
}

/// Builds a cloud row that satisfies [spec]'s transfer columns, hybrid guard
/// and FK references (referenced parents are generated with the same `n` so
/// the dependency-ordered syncAll run always resolves them).
Map<String, Object?> _validRow(MasterCatalogSpec spec, int n) {
  final Map<String, Object?> row = <String, Object?>{
    'id': 'uuid-$n-${spec.catalog}',
    'created_at': '2026-01-01T07:00:00Z',
    'updated_at': '2026-01-01T08:00:00Z',
    'deleted_at': null,
    'row_version': 1,
  };
  if (spec.hybrid) row['user_id'] = null;
  for (final MasterCatalogColumn column in spec.columns) {
    final bool isKey = column.cloud == spec.naturalKeyCloud;
    final bool isBool = spec.booleanColumns.contains(column.cloud);
    row[column.cloud] = isBool ? false : (isKey ? 'key-$n' : 'value-$n');
  }
  for (final MapEntry<String, String> fk in spec.cloudForeignKeys.entries) {
    row[fk.key] = 'uuid-$n-${_catalogForTable(fk.value)}';
  }
  return row;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late Database db;
  late MasterCatalogStateLocalDataSource stateDao;

  Future<void> setUpDb() async {
    await databaseFactory.deleteDatabase(await _databasePath());
    appDatabase = AppDatabase();
    db = await appDatabase.database;
    stateDao = MasterCatalogStateLocalDataSource(database: appDatabase);
  }

  tearDown(() async {
    await appDatabase.close();
  });

  MasterDataSyncService service(_FakeMasterTransport transport) =>
      MasterDataSyncService(
        database: appDatabase,
        transport: transport,
        stateDataSource: stateDao,
      );

  Future<Map<String, Object?>> rowById(String table, int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return rows.first;
  }

  group('registry', () {
    setUp(setUpDb);

    test('registers every catalog in dependency order', () {
      expect(
        MasterCatalogRegistry.catalogs.map((s) => s.catalog),
        <String>[
          'workout_categories',
          'meal_categories',
          'foods',
          'exercises',
          'goal_templates',
          'workout_templates',
          'workout_template_exercises',
          'achievement_defs',
          'badge_defs',
          'challenge_defs',
        ],
      );
    });

    test('foods/exercises are hybrid and map image_url back', () {
      final MasterCatalogSpec foods = MasterCatalogRegistry.catalogs[2];
      expect(foods.hybrid, isTrue);
      expect(
        foods.columns.any(
          (c) => c.cloud == 'image_url' && c.local == 'image_path',
        ),
        isTrue,
      );
      final MasterCatalogSpec exercises = MasterCatalogRegistry.catalogs[3];
      expect(exercises.hybrid, isTrue);
      expect(
        exercises.columns.any(
          (c) => c.cloud == 'gif_url' && c.local == 'gif_path',
        ),
        isTrue,
      );
    });
  });

  group('fresh install', () {
    setUp(setUpDb);

    test('downloads the catalog and stores version + watermark', () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('achievement_defs', 1);
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(id: 'ach-uuid-1', achievementType: 'streak_7', name: 'On a roll'),
      );
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(id: 'ach-uuid-2', achievementType: 'first_workout', name: 'Getting started'),
      );

      final MasterCatalogSyncResult result =
          await service(transport).syncCatalog('achievement_defs');

      expect(result.succeeded, isTrue);
      expect(result.applied, 2);
      expect(result.dataVersion, 1);

      final List<Map<String, Object?>> local = await db.query('achievement_def');
      expect(local, hasLength(2));
      expect(
        local.map((r) => r['uuid']).toSet(),
        <Object?>{'ach-uuid-1', 'ach-uuid-2'},
      );
      expect(transport.lastSince, isNull,
          reason: 'fresh install pulls everything (no watermark)');

      final MasterCatalogState state = (await stateDao.get('achievement_defs'))!;
      expect(state.dataVersion, 1);
      expect(state.status, 'success');
      expect(state.appliedAt, isNotNull);
      expect(
        state.sinceMs,
        _msOf('2026-01-01T08:00:00Z'),
        reason: 'watermark is the max applied updated_at',
      );
    });

    test('syncAll downloads every catalog that has a published version',
        () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      for (final MasterCatalogSpec spec in MasterCatalogRegistry.catalogs) {
        transport.addVersion(spec.catalog, 1);
        transport.addRow(spec.catalog, _validRow(spec, 1));
        transport.addRow(spec.catalog, _validRow(spec, 2));
      }

      final MasterDataSyncResult result = await service(transport).syncAll();

      expect(result.hasErrors, isFalse);
      expect(result.catalogs, hasLength(10));
      for (final MasterCatalogSyncResult catalog in result.catalogs) {
        expect(catalog.succeeded, isTrue, reason: catalog.catalog);
        expect(catalog.dataVersion, 1);
        expect(catalog.applied, 2, reason: catalog.catalog);
      }
      final List<MasterCatalogState> states = await stateDao.getAll();
      expect(states, hasLength(10));
      expect(states.every((s) => s.status == 'success'), isTrue);
    });
  });

  group('existing install', () {
    setUp(setUpDb);

    test('skips the download when the version is unchanged', () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('achievement_defs', 1);
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(id: 'ach-uuid-1', achievementType: 'streak_7', name: 'On a roll'),
      );

      await service(transport).syncCatalog('achievement_defs');
      final int pullsAfterFirst = transport.pullCalls;

      final MasterCatalogSyncResult second =
          await service(transport).syncCatalog('achievement_defs');

      expect(second.skipped, isTrue);
      expect(second.succeeded, isTrue);
      expect(second.applied, 0);
      expect(transport.pullCalls, pullsAfterFirst,
          reason: 'no pull when the server version matches the stored one');
    });

    test('retries after a failed attempt even with the same version', () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('achievement_defs', 1);
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(id: 'ach-uuid-1', achievementType: 'streak_7', name: 'On a roll'),
      );
      transport.failOnPullIndex = 1;

      final MasterCatalogSyncResult failed =
          await service(transport).syncCatalog('achievement_defs');
      expect(failed.failed, isTrue);
      expect(failed.dataVersion, 0);

      transport.failOnPullIndex = -1;
      final MasterCatalogSyncResult retry =
          await service(transport).syncCatalog('achievement_defs');
      expect(retry.succeeded, isTrue);
      expect((await stateDao.get('achievement_defs'))!.status, 'success');
    });
  });

  group('incremental pull on version change', () {
    setUp(setUpDb);

    test('pulls only rows updated at/after the stored watermark', () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('achievement_defs', 1);
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(
          id: 'ach-uuid-1',
          achievementType: 'streak_7',
          name: 'On a roll',
          updatedAt: '2026-01-01T08:00:00Z',
        ),
      );
      await service(transport).syncCatalog('achievement_defs');

      // Server publishes version 2 with a new def + an edit to the old one.
      // Clear the row store so it reflects the server's current rows only.
      transport.versions.clear();
      transport.rows.clear();
      transport.addVersion('achievement_defs', 2);
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(
          id: 'ach-uuid-1',
          achievementType: 'streak_7',
          name: 'On a roll (updated)',
          updatedAt: '2026-01-02T10:00:00Z',
        ),
      );
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(
          id: 'ach-uuid-3',
          achievementType: 'hydration_master',
          name: 'Hydration master',
          updatedAt: '2026-01-02T11:00:00Z',
        ),
      );

      final MasterCatalogSyncResult result =
          await service(transport).syncCatalog('achievement_defs');

      expect(result.succeeded, isTrue);
      expect(result.applied, 2);
      expect(transport.lastSince, isNotNull,
          reason: 'incremental pulls anchor on the stored watermark');
      final MasterCatalogState state = (await stateDao.get('achievement_defs'))!;
      expect(state.dataVersion, 2);
      expect(
        state.sinceMs,
        _msOf('2026-01-02T11:00:00Z'),
        reason: 'watermark advances to the newest row seen',
      );

      final List<Map<String, Object?>> local = await db.query('achievement_def');
      expect(local, hasLength(2),
          reason: '1 edited in place + 1 new');
      final Map<String, Object?> streak = local.firstWhere(
        (r) => r['achievement_type'] == 'streak_7',
      );
      expect(streak['uuid'], 'ach-uuid-1',
          reason: 'existing row adopted and edited in place');
      expect(streak['name'], 'On a roll (updated)');
    });
  });

  group('failure handling', () {
    setUp(setUpDb);

    test('network failure keeps old data and records the error', () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('achievement_defs', 1);
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(id: 'ach-uuid-1', achievementType: 'streak_7', name: 'On a roll'),
      );
      await service(transport).syncCatalog('achievement_defs');

      transport.failVersions = true;
      final MasterCatalogSyncResult failed =
          await service(transport).syncCatalog('achievement_defs');

      expect(failed.failed, isTrue);
      expect(failed.error, 'network_down');
      expect((await db.query('achievement_def')), hasLength(1),
          reason: 'old catalog untouched');
      final MasterCatalogState state =
          (await stateDao.get('achievement_defs'))!;
      expect(state.dataVersion, 1, reason: 'version does not advance');
      expect(state.status, 'failed');
      expect(state.lastError, 'network_down');
    });

    test('partial download rolls back the uncommitted batch but keeps prior '
        'data and version', () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('foods', 1);
      for (int i = 1; i <= 5; i++) {
        transport.addRow(
          'foods',
          _foodRow(
            id: 'food-uuid-$i',
            name: 'Food $i',
            updatedAt: '2026-01-01T08:00:0${i}Z',
          ),
        );
      }
      await service(transport).syncCatalog('foods');
      expect((await stateDao.get('foods'))!.dataVersion, 1);

      // Version 2 arrives; the pull fails on the second batch.
      transport.versions.clear();
      transport.addVersion('foods', 2);
      transport.addRow(
        'foods',
        _foodRow(id: 'food-uuid-6', name: 'Food 6', updatedAt: '2026-01-02T09:00:00Z'),
      );
      transport.addRow(
        'foods',
        _foodRow(id: 'food-uuid-7', name: 'Food 7', updatedAt: '2026-01-02T09:05:00Z'),
      );
      // pullCalls is already 1 from the v1 run, so the v2 run's first pull is
      // call #2 — fail it to simulate a mid-download outage.
      transport.failOnPullIndex = 2;

      final MasterCatalogSyncResult failed =
          await service(transport).syncCatalog('foods');

      expect(failed.failed, isTrue);
      final MasterCatalogState state = (await stateDao.get('foods'))!;
      expect(state.dataVersion, 1, reason: 'version stays at last good');
      expect(state.status, 'failed');
      expect(state.lastError, 'partial_failure');
      expect(
        state.sinceMs,
        _msOf('2026-01-01T08:00:05Z'),
        reason: 'watermark stays at the last fully committed run',
      );
      final List<Map<String, Object?>> local = await db.query('food_item');
      expect(local, hasLength(5), reason: 'prior catalog fully intact');
      expect(
        local.map((r) => r['name']),
        isNot(contains('Food 6')),
        reason: 'the failed batch was rolled back (transaction per batch)',
      );
    });
  });

  group('large catalog', () {
    setUp(setUpDb);

    test('downloads a multi-batch catalog across pages', () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('foods', 1);
      for (int i = 1; i <= 250; i++) {
        transport.addRow(
          'foods',
          _foodRow(
            id: 'food-uuid-$i',
            name: 'Food $i',
            updatedAt: '2026-01-01T08:00:00Z',
          ),
        );
      }

      final MasterCatalogSyncResult result =
          await service(transport).syncCatalog('foods');

      expect(result.succeeded, isTrue);
      expect(result.applied, 250);
      expect(result.batches, greaterThan(1),
          reason: 'catalog larger than one pull batch is paged');
      final List<Map<String, Object?>> local = await db.query('food_item');
      expect(local, hasLength(250));
    });
  });

  group('idempotency and duplicates', () {
    setUp(setUpDb);

    test('duplicate rows within a page are applied once', () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('achievement_defs', 1);
      // Same cloud uuid repeated (e.g. a racing publish): applied once.
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(id: 'ach-uuid-1', achievementType: 'streak_7', name: 'On a roll'),
      );
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(id: 'ach-uuid-1', achievementType: 'streak_7', name: 'On a roll'),
      );

      final MasterCatalogSyncResult result =
          await service(transport).syncCatalog('achievement_defs');

      expect(result.applied, 2);
      final List<Map<String, Object?>> local = await db.query('achievement_def');
      expect(local, hasLength(1),
          reason: 'same uuid upserts in place instead of inserting twice');
      expect(local.single['uuid'], 'ach-uuid-1');
    });

    test('re-running a data bump does not duplicate rows', () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('achievement_defs', 1);
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(id: 'ach-uuid-1', achievementType: 'streak_7', name: 'On a roll'),
      );

      final MasterDataSyncService svc = service(transport);
      await svc.syncCatalog('achievement_defs');

      // A data-only bump: version 2 re-publishes the same row (same updated_at
      // as the stored watermark) so it is re-fetched, but the upsert must stay
      // idempotent.
      transport.versions.clear();
      transport.addVersion('achievement_defs', 2);
      transport.addRow(
        'achievement_defs',
        _achievementDefRow(
          id: 'ach-uuid-1',
          achievementType: 'streak_7',
          name: 'On a roll',
          updatedAt: '2026-01-01T08:00:00Z',
        ),
      );
      await svc.syncCatalog('achievement_defs');

      final List<Map<String, Object?>> local = await db.query('achievement_def');
      expect(local, hasLength(1));
      expect(local.single['name'], 'On a roll');
      expect(local.single['uuid'], 'ach-uuid-1');
    });
  });

  group('natural-key adoption and FK resolution', () {
    setUp(setUpDb);

    test('adopts seeded categories in place preserving ids', () async {
      // Simulate the offline seed: a category row without a uuid. Use a slug
      // that is not part of the migration's default 21-category seed.
      await db.insert('workout_category', <String, Object?>{
        'name': 'Premium',
        'slug': 'premium',
        'sort_order': 3,
        'created_at': 0,
        'updated_at': 0,
      });
      final int seededId =
          (await db.query('workout_category', where: "slug = 'premium'"))
              .single['id'] as int;

      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('workout_categories', 1);
      transport.addRow(
        'workout_categories',
        _categoryRow(
          id: 'cat-uuid-1',
          name: 'Premium Zone',
          slug: 'premium',
          sortOrder: 9,
        ),
      );

      final MasterCatalogSyncResult result =
          await service(transport).syncCatalog('workout_categories');

      expect(result.succeeded, isTrue);
      final Map<String, Object?> row =
          await rowById('workout_category', seededId);
      expect(row['uuid'], 'cat-uuid-1');
      expect(row['name'], 'Premium Zone', reason: 'metadata refreshed');
      expect(row['sort_order'], 9);
      expect(
        await db.query('workout_category', where: "slug = 'premium'"),
        hasLength(1),
        reason: 'adopted in place, not duplicated',
      );
    });

    test('resolves template category/exercise FKs to local integer ids',
        () async {
      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('workout_categories', 1);
      transport.addRow(
        'workout_categories',
        _categoryRow(id: 'cat-uuid-1', name: 'Cardio', slug: 'cardio'),
      );
      transport.addVersion('exercises', 1);
      transport.addRow(
        'exercises',
        _exerciseRow(id: 'ex-uuid-1', name: 'Push-up'),
      );
      transport.addVersion('workout_templates', 1);
      transport.addRow(
        'workout_templates',
        _templateRow(
          id: 'tpl-uuid-1',
          name: 'Quick Cardio',
          categoryId: 'cat-uuid-1',
        ),
      );
      transport.addVersion('workout_template_exercises', 1);
      transport.addRow(
        'workout_template_exercises',
        _templateExerciseRow(
          id: 'tpl-ex-uuid-1',
          templateId: 'tpl-uuid-1',
          exerciseId: 'ex-uuid-1',
        ),
      );

      final MasterDataSyncService svc = service(transport);
      await svc.syncCatalog('workout_categories');
      await svc.syncCatalog('exercises');
      await svc.syncCatalog('workout_templates');
      final MasterCatalogSyncResult links =
          await svc.syncCatalog('workout_template_exercises');

      expect(links.succeeded, isTrue);

      final Map<String, Object?> category =
          (await db.query('workout_category', where: "slug = 'cardio'")).single;
      final Map<String, Object?> exercise =
          (await db.query('exercise', where: "name = 'Push-up'")).single;
      final Map<String, Object?> template =
          (await db.query('workout_template', where: "name = 'Quick Cardio'"))
              .single;
      final List<Map<String, Object?>> linkRows =
          await db.query('workout_template_exercise');

      expect(template['category_id'], category['id'],
          reason: 'cloud category uuid resolved to the local int id');
      expect(linkRows, hasLength(1));
      expect(linkRows.single['template_id'], template['id']);
      expect(linkRows.single['exercise_id'], exercise['id']);
    });
  });

  group('hybrid isolation', () {
    setUp(setUpDb);

    test('master rows get user_id NULL and user rows are never touched',
        () async {
      await db.insert('users', <String, Object?>{
        'id': 'user-1',
        'name': 'Alice',
        'email': 'a@x.com',
        'provider': 'email',
      });
      // A custom food that shares a master name must not be stomped.
      await db.insert('food_item', <String, Object?>{
        'user_id': 'user-1',
        'name': 'Rice',
        'calories': 999.0,
        'is_custom': 1,
        'created_at': 0,
      });
      final int customId =
          (await db.query('food_item', where: 'user_id = ?', whereArgs: <Object?>['user-1']))
              .single['id'] as int;

      final _FakeMasterTransport transport = _FakeMasterTransport();
      transport.addVersion('foods', 1);
      transport.addRow(
        'foods',
        _foodRow(id: 'master-rice-uuid', name: 'Rice'),
      );

      final MasterCatalogSyncResult result =
          await service(transport).syncCatalog('foods');

      expect(result.succeeded, isTrue);
      final List<Map<String, Object?>> rows =
          await db.query('food_item', orderBy: 'id ASC');
      expect(rows, hasLength(2));

      final Map<String, Object?> custom = await rowById('food_item', customId);
      expect(custom['user_id'], 'user-1');
      expect(custom['calories'], 999.0, reason: 'user row untouched');
      expect(custom['uuid'], isNull,
          reason: 'master sync never assigns a uuid to a user row');

      final Map<String, Object?> master = rows.firstWhere(
        (r) => r['id'] != customId,
      );
      expect(master['user_id'], isNull);
      expect(master['uuid'], 'master-rice-uuid');
      expect(master['calories'], 130.0);
    });
  });

  group('offline', () {
    setUp(setUpDb);

    test('a transport that is not ready leaves local data alone', () async {
      final _FakeMasterTransport transport = _FakeMasterTransport(ready: false);
      transport.addVersion('workout_categories', 1);

      final MasterDataSyncResult result = await service(transport).syncAll();

      expect(result.ran, isFalse);
      expect(result.catalogs, isEmpty);
      expect(await db.query('workout_category'), isNotEmpty,
          reason: 'seeded catalog stays usable offline');
      expect(await stateDao.getAll(), isEmpty);
    });
  });
}
