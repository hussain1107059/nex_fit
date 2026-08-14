import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/exercise_local_data_source.dart';
import 'package:nexfit/data/datasources/local/food_item_local_data_source.dart';
import 'package:nexfit/data/datasources/local/level_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_state_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/repositories/sync_state_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/data/services/sync/sync_table_registry.dart';
import 'package:nexfit/domain/entities/common_enums.dart';
import 'package:nexfit/domain/entities/exercise.dart';
import 'package:nexfit/domain/entities/exercise_category.dart';
import 'package:nexfit/domain/entities/food_item.dart';
import 'package:nexfit/domain/entities/level.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/entities/sync_state.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 15 Batch 5 DAO migration tests — the last two user-syncable tables:
/// `food_item` (custom rows only) and `user_level` (singleton).
///
/// food_item is a hybrid table: master rows (`user_id IS NULL`, seeded by
/// `FoodSeeder`) stay local-only and must NEVER emit an outbox event, while
/// custom rows (user-owned) follow the full transactional outbox contract
/// (uuid, row_version, base_version, soft-delete, remote apply without echo).
///
/// user_level is a per-user singleton (`UNIQUE(user_id)`). It follows the
/// user_profile / app_settings pattern: uuid == user_id, upsert is a
/// create/update pair so row_version and created_at survive, and deletes are
/// soft-deletes.

final RegExp _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), 'nexfit.db');
}

/// Scripted transport used for incremental-pull engine tests.
class _PullTransport implements SyncTransport {
  _PullTransport({List<SyncChange>? remoteChanges})
      : remoteChanges = remoteChanges ?? <SyncChange>[];

  final List<SyncChange> remoteChanges;

  @override
  String get name => 'scripted';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async =>
      const SyncPushResult(applied: true, serverRowVersion: 1);

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    final List<SyncChange> due = remoteChanges
        .where((SyncChange c) => c.cursorId > cursor)
        .toList();
    return SyncPullBatch(
      changes: due,
      nextCursor: due.isEmpty ? cursor : due.last.cursorId,
      hasMore: due.length == limit,
    );
  }
}

/// Transport that reports an optimistic-lock conflict on push.
class _ConflictTransport implements SyncTransport {
  @override
  String get name => 'conflict';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) async =>
      const SyncPushResult(applied: false, conflict: true);

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async =>
      const SyncPullBatch(
        changes: <SyncChange>[],
        nextCursor: 0,
        hasMore: false,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late Database db;
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
    await db.insert('users', <String, Object?>{
      'id': 'user-2',
      'name': 'Bob',
      'email': 'bob@x.com',
      'provider': 'email',
    });
    applier = RemoteChangeApplier(database: appDatabase);
    SyncEventRecorder.configure(
      repository: SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      ),
      deviceIdProvider: () async => 'device-1',
      activeUserId: 'user-1',
    );
  }

  tearDown(() async {
    SyncEventRecorder.setEnabled(false);
    SyncEventRecorder.setActiveUser(null);
    await appDatabase.close();
  });

  Future<List<Map<String, Object?>>> eventsFor(String entity) {
    return db.query(
      'sync_event',
      where: 'entity = ?',
      whereArgs: <Object?>[entity],
      orderBy: 'id ASC',
    );
  }

  Future<Map<String, Object?>> rowById(String table, int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return rows.first;
  }

  FoodItem customFood({String? userId = 'user-1'}) => FoodItem(
        userId: userId,
        name: 'Protein shake',
        brand: 'MyBrand',
        category: 'Supplements',
        servingSize: '1 scoop',
        servingGrams: 30,
        calories: 120,
        protein: 24,
        carbs: 3,
        fat: 1.5,
        fiber: 0,
        sugar: 1,
        sodium: 50,
        potassium: 150,
        calcium: 100,
        iron: 1,
        vitaminA: 0,
        vitaminC: 0,
        waterPercentage: 5,
        barcode: '8901234567890',
        imagePath: 'assets/food/shake.png',
        isCustom: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  FoodItem masterFood() => FoodItem(
        name: 'Rice',
        category: 'Grains',
        servingGrams: 100,
        calories: 130,
        protein: 2.7,
        carbs: 28,
        fat: 0.3,
        isCustom: false,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  LevelProgress level({String userId = 'user-1'}) => LevelProgress(
        userId: userId,
        level: 3,
        currentXp: 250,
        requiredXp: 300,
        totalXp: 750,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  Exercise customExercise({String? userId = 'user-1'}) => Exercise(
        userId: userId,
        name: 'Cable curl',
        scientificName: 'Brachialis curl',
        description: 'Biceps isolation',
        instructions: 'Keep elbows pinned',
        bodyPart: 'Biceps',
        secondaryMuscle: 'Forearms',
        equipment: 'cable',
        difficulty: Difficulty.beginner,
        category: ExerciseCategory.arms,
        image: 'assets/exercise/curl.png',
        gifPath: 'assets/exercise/curl.gif',
        caloriesPerMinute: 5,
        estimatedCalories: 50,
        durationSeconds: 30,
        sets: 3,
        reps: 12,
        restSeconds: 30,
        tips: const <String>['Squeeze at the top'],
        commonMistakes: const <String>['Swinging'],
        safetyInstructions: const <String>['Warm up'],
        isCustom: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  Exercise masterExercise() => Exercise(
        name: 'Push-up',
        bodyPart: 'Chest',
        difficulty: Difficulty.beginner,
        category: ExerciseCategory.chest,
        isCustom: false,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  group('food_item (custom rows)', () {
    setUp(setUpDb);

    FoodItemLocalDataSource dao() =>
        FoodItemLocalDataSource(database: appDatabase);

    test('inserting a custom row stamps uuid, version 1 and a CREATE event',
        () async {
      final int id = await dao().insert(customFood());
      final Map<String, Object?> row = await rowById('food_item', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['user_id'], 'user-1');
      expect(row['is_custom'], 1);
      final List<Map<String, Object?>> events = await eventsFor('food_item');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
      expect(events.single['user_id'], 'user-1');
    });

    test('inserting a master row creates no outbox event', () async {
      final int id = await dao().insert(masterFood());
      final Map<String, Object?> row = await rowById('food_item', id);
      expect(row['user_id'], isNull);
      expect(row['uuid'], isNull,
          reason: 'master rows stay local-only; no cloud identity');
      expect(await eventsFor('food_item'), isEmpty);
    });

    test('update preserves uuid and records base_version', () async {
      final int id = await dao().insert(customFood());
      final String uuid = (await rowById('food_item', id))['uuid'] as String;

      await dao().update(
        customFood().copyWith(
          id: id,
          name: 'Protein shake double',
          calories: 240,
        ),
      );

      final Map<String, Object?> row = await rowById('food_item', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['calories'], 240);
      final List<Map<String, Object?>> events = await eventsFor('food_item');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('updating a master row creates no outbox event', () async {
      final int id = await dao().insert(masterFood());
      await dao().update(masterFood().copyWith(id: id, calories: 140));
      expect((await rowById('food_item', id))['calories'], 140);
      expect(await eventsFor('food_item'), isEmpty);
    });

    test('delete soft-deletes a custom row and hides it from reads', () async {
      final int id = await dao().insert(customFood());
      await dao().delete(id);

      final Map<String, Object?> row = await rowById('food_item', id);
      expect(row['deleted_at'], isNotNull);
      expect(await dao().getById(id), isNull);
      expect(
        await dao().getCatalog('user-1'),
        everyElement(predicate((FoodItem f) => f.id != id)),
      );
      final List<Map<String, Object?>> events = await eventsFor('food_item');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('deleting a master row is a no-op (no tombstone, no event)', () async {
      final int id = await dao().insert(masterFood());
      await dao().delete(id);
      final Map<String, Object?> row = await rowById('food_item', id);
      expect(row['deleted_at'], isNull,
          reason: 'the shared catalog must never be tombstoned via sync');
      expect(await eventsFor('food_item'), isEmpty);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(
        dao().insert(customFood(userId: 'ghost')),
        throwsA(isA<Object>()),
      );
      expect(await db.query('food_item'), isEmpty);
      expect(await eventsFor('food_item'), isEmpty);
    });

    test('remote apply maps all columns incl image_url and is_custom, no echo',
        () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'foods',
            recordId: 'food-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'food-uuid-1',
              'user_id': 'user-1',
              'name': 'Chicken breast',
              'brand': 'Farm',
              'category': 'Proteins',
              'serving_size': '100g',
              'serving_grams': 100.0,
              'calories': 165.0,
              'protein': 31.0,
              'carbs': 0.0,
              'fat': 3.6,
              'fiber': 0.0,
              'sugar': 0.0,
              'sodium': 74.0,
              'potassium': 256.0,
              'calcium': 12.0,
              'iron': 1.0,
              'vitamin_a': 0.0,
              'vitamin_c': 0.0,
              'water_percentage': 65.0,
              'barcode': '0123456789',
              'image_url': 'assets/food/chicken.png',
              'is_custom': true,
              'created_at': '2026-01-01T08:00:00Z',
              'updated_at': '2026-01-01T08:00:00Z',
              'deleted_at': null,
              'row_version': 1,
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query('food_item');
      expect(rows, hasLength(1));
      final Map<String, Object?> row = rows.single;
      expect(row['uuid'], 'food-uuid-1');
      expect(row['name'], 'Chicken breast');
      expect(row['image_path'], 'assets/food/chicken.png',
          reason: 'cloud image_url maps back to local image_path');
      expect(row['is_custom'], 1);
      expect(row['protein'], 31.0);
      expect(await eventsFor('food_item'), isEmpty);
    });

    test('events carry their own user (per-user scoping)', () async {
      await dao().insert(customFood());
      await dao().insert(customFood(userId: 'user-2'));
      final List<Map<String, Object?>> events = await eventsFor('food_item');
      expect(events, hasLength(2));
      expect(
        events.map((e) => e['user_id']).toSet(),
        <Object?>{'user-1', 'user-2'},
      );
    });
  });

  group('exercise (custom rows)', () {
    setUp(setUpDb);

    ExerciseLocalDataSource dao() =>
        ExerciseLocalDataSource(database: appDatabase);

    test('inserting a custom row stamps uuid, version 1 and a CREATE event',
        () async {
      final int id = await dao().insert(customExercise());
      final Map<String, Object?> row = await rowById('exercise', id);
      expect(row['uuid'], matches(_uuidRegex));
      expect(row['row_version'], 1);
      expect(row['user_id'], 'user-1');
      expect(row['is_custom'], 1);
      final List<Map<String, Object?>> events = await eventsFor('exercise');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], '$id');
      expect(events.single['user_id'], 'user-1');
    });

    test('inserting a master row creates no outbox event', () async {
      final int id = await dao().insert(masterExercise());
      final Map<String, Object?> row = await rowById('exercise', id);
      expect(row['user_id'], isNull);
      expect(row['uuid'], isNull);
      expect(await eventsFor('exercise'), isEmpty);
    });

    test('update preserves uuid and records base_version', () async {
      final int id = await dao().insert(customExercise());
      final String uuid = (await rowById('exercise', id))['uuid'] as String;

      await dao().update(
        customExercise().copyWith(id: id, name: 'Cable hammer curl'),
      );

      final Map<String, Object?> row = await rowById('exercise', id);
      expect(row['uuid'], uuid);
      expect(row['row_version'], 2);
      expect(row['name'], 'Cable hammer curl');
      final List<Map<String, Object?>> events = await eventsFor('exercise');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('updating a master row creates no outbox event', () async {
      final int id = await dao().insert(masterExercise());
      await dao().update(masterExercise().copyWith(id: id, name: 'Wide push-up'));
      expect((await rowById('exercise', id))['name'], 'Wide push-up');
      expect(await eventsFor('exercise'), isEmpty);
    });

    test('delete soft-deletes a custom row and hides it from reads', () async {
      final int id = await dao().insert(customExercise());
      await dao().delete(id);

      final Map<String, Object?> row = await rowById('exercise', id);
      expect(row['deleted_at'], isNotNull);
      expect(await dao().getById(id), isNull);
      expect(
        await dao().getAll('user-1'),
        everyElement(predicate((Exercise e) => e.id != id)),
      );
      final List<Map<String, Object?>> events = await eventsFor('exercise');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['base_version'], 1);
    });

    test('deleting a master row is a no-op (no tombstone, no event)', () async {
      final int id = await dao().insert(masterExercise());
      await dao().delete(id);
      expect((await rowById('exercise', id))['deleted_at'], isNull);
      expect(await eventsFor('exercise'), isEmpty);
    });

    test('a failing insert (unknown user) rolls back row and event', () async {
      await expectLater(
        dao().insert(customExercise(userId: 'ghost')),
        throwsA(isA<Object>()),
      );
      expect(await db.query('exercise'), isEmpty);
      expect(await eventsFor('exercise'), isEmpty);
    });

    test('remote apply maps all columns incl image_url/gif_url, no echo',
        () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'exercises',
            recordId: 'ex-uuid-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'ex-uuid-1',
              'user_id': 'user-1',
              'name': 'Romanian deadlift',
              'scientific_name': 'Stiff-leg deadlift',
              'description': 'Posterior chain',
              'instructions': 'Hinge at the hips',
              'body_part': 'Hamstrings',
              'secondary_muscle': 'Glutes, Lower back',
              'equipment': 'barbell',
              'difficulty': 'intermediate',
              'category': 'legs',
              'image_url': 'assets/exercise/rdl.png',
              'gif_url': 'assets/exercise/rdl.gif',
              'calories_per_minute': 8.0,
              'estimated_calories': 80.0,
              'duration_seconds': 30,
              'sets': 4,
              'reps': 10,
              'rest_seconds': 60,
              'tips': 'Keep the bar close',
              'common_mistakes': 'Rounding the back',
              'safety_instructions': 'Use a light load',
              'is_custom': true,
              'created_at': '2026-01-01T08:00:00Z',
              'updated_at': '2026-01-01T08:00:00Z',
              'deleted_at': null,
              'row_version': 1,
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query('exercise');
      expect(rows, hasLength(1));
      final Map<String, Object?> row = rows.single;
      expect(row['uuid'], 'ex-uuid-1');
      expect(row['name'], 'Romanian deadlift');
      expect(row['image'], 'assets/exercise/rdl.png',
          reason: 'cloud image_url maps back to local image');
      expect(row['gif_path'], 'assets/exercise/rdl.gif',
          reason: 'cloud gif_url maps back to local gif_path');
      expect(row['is_custom'], 1);
      expect(row['sets'], 4);
      expect(await eventsFor('exercise'), isEmpty);
    });
  });

  group('user_level (singleton)', () {
    setUp(setUpDb);

    LevelLocalDataSource dao() => LevelLocalDataSource(database: appDatabase);

    test('upsert creates the row with uuid = user_id and a CREATE event',
        () async {
      await dao().upsert(level());
      final List<Map<String, Object?>> rows = await db.query('user_level');
      expect(rows, hasLength(1));
      expect(rows.single['uuid'], 'user-1');
      expect(rows.single['row_version'], 1);
      expect(rows.single['level'], 3);
      final List<Map<String, Object?>> events =
          await eventsFor('user_level');
      expect(events.single['operation'], SyncOperation.create.name);
      expect(events.single['entity_id'], 'user-1');
    });

    test('upsert on an existing row preserves uuid/created_at and bumps version',
        () async {
      await dao().upsert(level());
      final Map<String, Object?> first = (await db.query('user_level')).single;
      final Object? created = first['created_at'];

      await dao().upsert(
        level().copyWith(level: 4, currentXp: 320, totalXp: 820),
      );

      final Map<String, Object?> row = (await db.query('user_level')).single;
      expect(row['uuid'], 'user-1');
      expect(row['created_at'], created);
      expect(row['row_version'], 2);
      expect(row['level'], 4);
      final List<Map<String, Object?>> events =
          await eventsFor('user_level');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('insert is idempotent for the same user', () async {
      final int id = await dao().insert(level());
      final int again = await dao().insert(level());
      expect(again, id);
      expect(await db.query('user_level'), hasLength(1));
      expect(await eventsFor('user_level'), hasLength(1));
    });

    test('delete soft-deletes and records a DELETE event', () async {
      await dao().upsert(level());
      final int id =
          (await db.query('user_level')).single['id'] as int;
      await dao().delete(id);

      final Map<String, Object?> row = (await db.query('user_level')).single;
      expect(row['deleted_at'], isNotNull);
      expect(await dao().getByUserId('user-1'), isNull);
      expect(await dao().getHistoryByUserId('user-1'), isEmpty);
      final List<Map<String, Object?>> events =
          await eventsFor('user_level');
      expect(events.last['operation'], SyncOperation.delete.name);
      expect(events.last['entity_id'], 'user-1');
      expect(events.last['base_version'], 1);
    });

    test('a failing upsert (unknown user) rolls back row and event', () async {
      await expectLater(
        dao().upsert(level(userId: 'ghost')),
        throwsA(isA<Object>()),
      );
      expect(await db.query('user_level'), isEmpty);
      expect(await eventsFor('user_level'), isEmpty);
    });

    test('remote apply upserts by user_id and never echoes', () async {
      await db.transaction((Transaction txn) async {
        await applier.apply(
          txn,
          SyncChange(
            cursorId: 1,
            cloudTable: 'user_levels',
            recordId: 'user-1',
            operation: SyncOperation.create,
            payload: <String, Object?>{
              'id': 'user-1',
              'user_id': 'user-1',
              'level': 5,
              'current_xp': 410,
              'required_xp': 500,
              'total_xp': 1210,
              'created_at': '2026-01-01T08:00:00Z',
              'updated_at': '2026-01-01T08:00:00Z',
              'deleted_at': null,
              'row_version': 1,
            },
          ),
        );
      });

      final List<Map<String, Object?>> rows = await db.query('user_level');
      expect(rows, hasLength(1));
      expect(rows.single['user_id'], 'user-1');
      expect(rows.single['level'], 5);
      expect(rows.single['total_xp'], 1210);
      expect(await eventsFor('user_level'), isEmpty);
    });
  });

  group('registry', () {
    test('food_item maps to foods with image_url rename and is_custom boolean',
        () {
      final SyncTableMapping? mapping =
          SyncTableRegistry.byLocalTable('food_item');
      expect(mapping, isNotNull);
      expect(mapping!.cloudTable, 'foods');
      expect(mapping.localToCloud['image_path'], 'image_url');
      expect(mapping.booleanColumns, contains('is_custom'));
      expect(mapping.localKeyColumn, 'id');
    });

    test('user_level maps to user_levels as a user_id singleton', () {
      final SyncTableMapping? mapping =
          SyncTableRegistry.byLocalTable('user_level');
      expect(mapping, isNotNull);
      expect(mapping!.cloudTable, 'user_levels');
      expect(mapping.localKeyColumn, 'user_id');
      expect(mapping.localToCloud['total_xp'], 'total_xp');
    });

    test('exercise maps to exercises with image_url/gif_url renames', () {
      final SyncTableMapping? mapping =
          SyncTableRegistry.byLocalTable('exercise');
      expect(mapping, isNotNull);
      expect(mapping!.cloudTable, 'exercises');
      expect(mapping.localToCloud['image'], 'image_url');
      expect(mapping.localToCloud['gif_path'], 'gif_url');
      expect(mapping.booleanColumns, contains('is_custom'));
    });
  });

  group('engine: incremental pull, ordering, conflicts', () {
    setUp(setUpDb);

    late SyncEventRepositoryImpl eventRepo;
    late SyncStateRepositoryImpl stateRepo;

    setUp(() async {
      eventRepo = SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      );
      stateRepo = SyncStateRepositoryImpl(
        SyncStateLocalDataSource(database: appDatabase),
      );
    });

    SyncEngine engine() => SyncEngine(
          repository: eventRepo,
          syncStateRepository: stateRepo,
          deviceIdProvider: () async => 'device-1',
        );

    SyncChange foodChange(
      int cursorId, {
      String recordId = 'food-uuid-1',
      String name = 'Rice',
    }) =>
        SyncChange(
          cursorId: cursorId,
          cloudTable: 'foods',
          recordId: recordId,
          operation: SyncOperation.create,
          payload: <String, Object?>{
            'id': recordId,
            'user_id': 'user-1',
            'name': name,
            'calories': 130.0,
            'protein': 2.7,
            'is_custom': true,
            'created_at': '2026-01-01T06:00:00Z',
            'updated_at': '2026-01-01T06:00:00Z',
            'deleted_at': null,
            'row_version': 1,
          },
        );

    test('incremental pull applies only changes after the stored cursor',
        () async {
      final SyncEngine syncEngine = engine();

      await syncEngine.pull(
        userId: 'user-1',
        transport: _PullTransport(
          remoteChanges: <SyncChange>[
            foodChange(5, recordId: 'food-uuid-1'),
            foodChange(6, recordId: 'food-uuid-2', name: 'Beans'),
          ],
        ),
        applier: applier,
      );
      final SyncState first = (await stateRepo.getByUserId('user-1'))!;
      expect(first.cursor, 6);
      expect(await db.query('food_item'), hasLength(2));

      // Second run only pulls cursor-7+ changes; 5/6 are never re-applied.
      await syncEngine.pull(
        userId: 'user-1',
        transport: _PullTransport(
          remoteChanges: <SyncChange>[
            foodChange(5, recordId: 'food-uuid-1'),
            foodChange(6, recordId: 'food-uuid-2', name: 'Beans'),
            foodChange(7, recordId: 'food-uuid-3', name: 'Lentils'),
          ],
        ),
        applier: applier,
      );
      final SyncState second = (await stateRepo.getByUserId('user-1'))!;
      expect(second.cursor, 7);
      expect(await db.query('food_item'), hasLength(3));
    });

    test('a foods-before-food_logs batch resolves the food FK', () async {
      await engine().pull(
        userId: 'user-1',
        transport: _PullTransport(
          remoteChanges: <SyncChange>[
            SyncChange(
              cursorId: 2,
              cloudTable: 'food_logs',
              recordId: 'fl-uuid-1',
              operation: SyncOperation.create,
              payload: <String, Object?>{
                'id': 'fl-uuid-1',
                'user_id': 'user-1',
                'food_id': 'food-uuid-1',
                'quantity': 2.0,
                'logged_at': '2026-01-01T07:00:00Z',
                'created_at': '2026-01-01T07:00:00Z',
                'updated_at': '2026-01-01T07:00:00Z',
                'deleted_at': null,
                'row_version': 1,
              },
            ),
            foodChange(1, recordId: 'food-uuid-1'),
          ],
        ),
        applier: applier,
      );

      final List<Map<String, Object?>> foods = await db.query('food_item');
      expect(foods, hasLength(1));
      final List<Map<String, Object?>> logs = await db.query('food_log');
      expect(logs, hasLength(1));
      expect(logs.single['food_item_id'], foods.single['id'],
          reason: 'cloud food_id uuid resolved back to the local int id');
    });

    test('an optimistic-lock conflict on push is resolved latest-wins',
        () async {
      final SyncEngine syncEngine = engine();
      await syncEngine.track(
        userId: 'user-1',
        entity: 'user_level',
        entityId: 'user-1',
        operation: SyncOperation.update,
        baseVersion: 1,
      );

      final SyncRunResult result = await syncEngine.processQueue(
        'user-1',
        transport: _ConflictTransport(),
      );

      expect(result.conflicts, 1);
      final List<SyncEvent> pending =
          await eventRepo.getPendingByUserId('user-1');
      expect(pending, isEmpty);
      expect(
        (await eventRepo.countByStatus('user-1'))[SyncStatus.completed.name],
        1,
        reason: 'latest-wins acknowledges the push; pull converges next',
      );
    });

    test('remote apply never enqueues an outbound event (no echo loop)',
        () async {
      await engine().pull(
        userId: 'user-1',
        transport: _PullTransport(
          remoteChanges: <SyncChange>[foodChange(5)],
        ),
        applier: applier,
      );
      expect(await eventRepo.getPendingCount('user-1'), 0);
      expect(await eventRepo.getFailedCount('user-1'), 0);
    });
  });
}
