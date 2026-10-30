import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/achievement_local_data_source.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/badge_local_data_source.dart';
import 'package:nexfit/data/datasources/local/streak_local_data_source.dart';
import 'package:nexfit/data/datasources/local/sync_event_local_data_source.dart';
import 'package:nexfit/data/repositories/sync_event_repository_impl.dart';
import 'package:nexfit/data/services/sync/remote_change_applier.dart';
import 'package:nexfit/data/services/sync/sync_contracts.dart';
import 'package:nexfit/data/services/sync/sync_event_recorder.dart';
import 'package:nexfit/data/services/sync/sync_table_registry.dart';
import 'package:nexfit/domain/entities/achievement.dart';
import 'package:nexfit/domain/entities/badge.dart';
import 'package:nexfit/domain/entities/common_enums.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/streak.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

/// PROMPT 34 Batch 6: gamification + streak tables join two-way sync.
///
/// These tables existed locally but recorded no outbox events and did not
/// maintain uuid/row_version, so their data could never reach Supabase. The
/// tests pin the transactional-outbox contract, the master-catalog FK
/// resolution (`*_def_id`) and the sync mapping shapes that must match the
/// deployed cloud columns exactly.
const String _databaseName = 'nexfit_batch6.db';

Future<String> _databasePath() async {
  return path.join(await databaseFactory.getDatabasesPath(), _databaseName);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late Database db;

  setUp(() async {
    await databaseFactory.deleteDatabase(await _databasePath());
    appDatabase = AppDatabase(databaseName: _databaseName);
    db = await appDatabase.database;
    await db.insert('users', <String, Object?>{
      'id': 'user-1',
      'name': 'Alice',
      'email': 'alice@x.com',
      'provider': 'email',
    });
    SyncEventRecorder.configure(
      repository: SyncEventRepositoryImpl(
        SyncEventLocalDataSource(database: appDatabase),
      ),
      deviceIdProvider: () async => 'device-1',
      activeUserId: 'user-1',
    );
  });

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

  Future<Map<String, Object?>> onlyRow(String table) async {
    final List<Map<String, Object?>> rows = await db.query(table);
    return rows.single;
  }

  Future<void> seedBadgeDef() async {
    await db.insert('badge_def', <String, Object?>{
      'uuid': 'def-badge-1',
      'badge_type': 'first_workout',
      'badge_name': 'First Step',
      'level': 1,
      'target': 1,
      'created_at': 1,
      'updated_at': 1,
    });
  }

  Future<void> seedAchievementDef() async {
    await db.insert('achievement_def', <String, Object?>{
      'uuid': 'def-ach-1',
      'achievement_type': 'first_workout',
      'name': 'First Workout',
      'created_at': 1,
      'updated_at': 1,
    });
  }

  Badge badge({int? id, double progress = 0, bool earned = false}) => Badge(
    id: id,
    userId: 'user-1',
    badgeType: 'first_workout',
    badgeName: 'First Step',
    level: 1,
    progress: progress,
    target: 1,
    isEarned: earned,
    earnedAt: earned ? DateTime.utc(2026, 1, 1) : null,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  group('badge sync DAO', () {
    test(
      'insert stamps sync columns, resolves badge_def_id and records CREATE',
      () async {
        await seedBadgeDef();
        final BadgeLocalDataSource source = BadgeLocalDataSource(
          database: appDatabase,
        );

        final int id = await source.insert(badge());
        final Map<String, Object?> row = await onlyRow('badge');

        expect(row['id'], id);
        expect(row['uuid'], isNotNull);
        expect(row['row_version'], 1);
        expect(row['badge_def_id'], 1);
        final List<Map<String, Object?>> events = await eventsFor('badge');
        expect(events, hasLength(1));
        expect(events.single['operation'], SyncOperation.create.name);
      },
    );

    test('update bumps the version and records base_version', () async {
      await seedBadgeDef();
      final BadgeLocalDataSource source = BadgeLocalDataSource(
        database: appDatabase,
      );
      final int id = await source.insert(badge());

      await source.update(badge(id: id, progress: 1, earned: true));
      final Map<String, Object?> row = await onlyRow('badge');
      expect(row['row_version'], 2);
      expect(row['is_earned'], 1);

      final List<Map<String, Object?>> events = await eventsFor('badge');
      expect(events, hasLength(2));
      expect(events.last['operation'], SyncOperation.update.name);
      expect(events.last['base_version'], 1);
    });

    test('an identical recomputation does not enqueue another event', () async {
      await seedBadgeDef();
      final BadgeLocalDataSource source = BadgeLocalDataSource(
        database: appDatabase,
      );
      final int id = await source.insert(badge(progress: 1, earned: true));

      await source.updateAll(<Badge>[badge(id: id, progress: 1, earned: true)]);
      expect(await eventsFor('badge'), hasLength(1));
    });

    test('delete is a tombstone and records DELETE', () async {
      await seedBadgeDef();
      final BadgeLocalDataSource source = BadgeLocalDataSource(
        database: appDatabase,
      );
      final int id = await source.insert(badge());

      await source.delete(id);
      final Map<String, Object?> row = await onlyRow('badge');
      expect(row['deleted_at'], isNotNull);
      expect(row['row_version'], 2);
      expect(await source.getByUserId('user-1'), isEmpty);
      final List<Map<String, Object?>> events = await eventsFor('badge');
      expect(events.last['operation'], SyncOperation.delete.name);
    });
  });

  group('achievement sync DAO', () {
    test(
      'insert resolves achievement_def_id and update records the unlock',
      () async {
        await seedAchievementDef();
        final AchievementLocalDataSource source = AchievementLocalDataSource(
          database: appDatabase,
        );

        final int id = await source.insert(
          Achievement(
            userId: 'user-1',
            name: 'First Workout',
            achievementType: 'first_workout',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
        final Map<String, Object?> row = await onlyRow('achievement');
        expect(row['uuid'], isNotNull);
        expect(row['row_version'], 1);
        expect(row['achievement_def_id'], 1);

        await source.update(
          Achievement(
            id: id,
            userId: 'user-1',
            name: 'First Workout',
            achievementType: 'first_workout',
            isUnlocked: true,
            unlockedAt: DateTime.utc(2026, 1, 2),
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
        final Map<String, Object?> updated = await onlyRow('achievement');
        expect(updated['row_version'], 2);
        expect(updated['is_unlocked'], 1);
        final List<Map<String, Object?>> events = await eventsFor(
          'achievement',
        );
        expect(events, hasLength(2));
        expect(events.last['operation'], SyncOperation.update.name);
        expect(events.last['base_version'], 1);
      },
    );
  });

  group('streak sync DAO', () {
    test(
      'upsert keeps id/uuid across writes and records create then update',
      () async {
        final StreakLocalDataSource source = StreakLocalDataSource(
          database: appDatabase,
        );
        final DateTime day = DateTime.utc(2026, 1, 1);

        final int id = await source.upsert(
          Streak(
            userId: 'user-1',
            streakType: StreakType.workout,
            currentStreak: 1,
            longestStreak: 1,
            lastActiveDate: day,
            createdAt: day,
            updatedAt: day,
          ),
        );
        final Map<String, Object?> created = await onlyRow('streak');
        expect(created['uuid'], isNotNull);
        expect(created['row_version'], 1);

        final int again = await source.upsert(
          Streak(
            userId: 'user-1',
            streakType: StreakType.workout,
            currentStreak: 2,
            longestStreak: 2,
            lastActiveDate: day,
            createdAt: day,
            updatedAt: day,
          ),
        );
        final Map<String, Object?> updated = await onlyRow('streak');
        expect(again, id);
        expect(updated['id'], id);
        expect(updated['uuid'], created['uuid']);
        expect(updated['row_version'], 2);
        expect(updated['current_streak'], 2);

        final List<Map<String, Object?>> events = await eventsFor('streak');
        expect(events, hasLength(2));
        expect(events.first['operation'], SyncOperation.create.name);
        expect(events.last['operation'], SyncOperation.update.name);
        expect(events.last['base_version'], 1);
      },
    );

    test('an unchanged recomputation is a no-op', () async {
      final StreakLocalDataSource source = StreakLocalDataSource(
        database: appDatabase,
      );
      final DateTime day = DateTime.utc(2026, 1, 1);
      final Streak streak = Streak(
        userId: 'user-1',
        streakType: StreakType.water,
        currentStreak: 3,
        longestStreak: 3,
        lastActiveDate: day,
        createdAt: day,
        updatedAt: day,
      );

      await source.upsert(streak);
      await source.upsert(streak);
      expect(await eventsFor('streak'), hasLength(1));
      expect((await onlyRow('streak'))['row_version'], 1);
    });
  });

  group('pulling gamification rows', () {
    SyncChange cloudBadgeChange({
      String recordId = 'cloud-badge-1',
      int progress = 1,
      int rowVersion = 1,
    }) {
      return SyncChange(
        cursorId: 1,
        cloudTable: 'user_badges',
        recordId: recordId,
        operation: SyncOperation.create,
        payload: <String, Object?>{
          'id': recordId,
          'user_id': 'user-1',
          'badge_id': 'def-badge-1',
          'level': 1,
          'progress': progress,
          'target': 1,
          'is_earned': true,
          'earned_at': '2026-01-01T00:00:00Z',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
          'row_version': rowVersion,
        },
      );
    }

    test('materialises the cloud row on a second device', () async {
      await seedBadgeDef();
      final RemoteChangeApplier applier = RemoteChangeApplier(
        database: appDatabase,
      );

      await db.transaction(
        (Transaction txn) => applier.apply(txn, cloudBadgeChange()),
      );

      final Map<String, Object?> row = await onlyRow('badge');
      expect(row['uuid'], 'cloud-badge-1');
      expect(row['badge_def_id'], 1);
      expect(row['badge_type'], 'first_workout');
      expect(row['badge_name'], 'First Step');
      expect(row['is_earned'], 1);
      expect(await eventsFor('badge'), isEmpty);
    });

    test('adopts the cloud uuid instead of duplicating a local row', () async {
      await seedBadgeDef();
      final BadgeLocalDataSource source = BadgeLocalDataSource(
        database: appDatabase,
      );
      final int localId = await source.insert(badge(progress: 1, earned: true));
      final Map<String, Object?> local = await onlyRow('badge');

      final RemoteChangeApplier applier = RemoteChangeApplier(
        database: appDatabase,
      );
      await db.transaction(
        (Transaction txn) => applier.apply(
          txn,
          cloudBadgeChange(recordId: 'cloud-badge-9', progress: 2),
        ),
      );

      final Map<String, Object?> row = await onlyRow('badge');
      expect(row['id'], localId);
      expect(row['uuid'], 'cloud-badge-9');
      expect(row['progress'], 2);
      expect(local['uuid'], isNot('cloud-badge-9'));
      expect(
        await eventsFor('badge'),
        hasLength(1),
        reason: 'remote apply never echoes an outbound event',
      );
    });

    test(
      'adopts a pre-master row whose def id is still NULL by its type',
      () async {
        await db.insert('badge', <String, Object?>{
          'uuid': 'local-badge-1',
          'user_id': 'user-1',
          'badge_type': 'first_workout',
          'badge_name': 'First Step',
          'level': 1,
          'progress': 0,
          'target': 1,
          'is_earned': 0,
          'created_at': 1,
          'updated_at': 1,
          'row_version': 1,
        });
        await seedBadgeDef();

        final RemoteChangeApplier applier = RemoteChangeApplier(
          database: appDatabase,
        );
        await db.transaction(
          (Transaction txn) => applier.apply(txn, cloudBadgeChange()),
        );

        final Map<String, Object?> row = await onlyRow('badge');
        expect(row['uuid'], 'cloud-badge-1');
        expect(row['badge_def_id'], 1);
        expect(row['progress'], 1);
        expect(row['is_earned'], 1);
      },
    );

    test(
      'a missing master definition is surfaced, not silently inserted',
      () async {
        final RemoteChangeApplier applier = RemoteChangeApplier(
          database: appDatabase,
        );
        await expectLater(
          db.transaction(
            (Transaction txn) => applier.apply(txn, cloudBadgeChange()),
          ),
          throwsA(isA<MissingMasterDefinitionException>()),
        );
        expect(await db.query('badge'), isEmpty);
      },
    );
  });

  group('mapping contract', () {
    test('only real cloud columns are mapped', () {
      final SyncTableMapping profile = SyncTableRegistry.byLocalTable(
        'user_profile',
      )!;
      expect(profile.localToCloud.containsKey('timezone'), isFalse);

      final SyncTableMapping badgeMapping = SyncTableRegistry.byLocalTable(
        'badge',
      )!;
      expect(badgeMapping.localToCloud.containsKey('badge_name'), isFalse);
      expect(badgeMapping.localToCloud.containsKey('icon'), isFalse);
      expect(badgeMapping.requiredCloudForeignKeys, contains('badge_def_id'));
      expect(badgeMapping.localNaturalKey, <String>['user_id', 'badge_type']);
      expect(badgeMapping.cloudNaturalKey, <String>['user_id', 'badge_id']);

      final SyncTableMapping achievement = SyncTableRegistry.byLocalTable(
        'achievement',
      )!;
      expect(achievement.localToCloud.containsKey('name'), isFalse);
      expect(achievement.localToCloud.containsKey('description'), isFalse);
      expect(achievement.localToCloud.containsKey('icon'), isFalse);
      expect(
        achievement.requiredCloudForeignKeys,
        contains('achievement_def_id'),
      );
      expect(achievement.localNaturalKey, <String>[
        'user_id',
        'achievement_type',
      ]);
      expect(achievement.cloudNaturalKey, <String>[
        'user_id',
        'achievement_id',
      ]);

      final SyncTableMapping challenge = SyncTableRegistry.byLocalTable(
        'challenge',
      )!;
      for (final String localOnly in <String>[
        'title',
        'description',
        'difficulty',
        'target',
        'reward_xp',
      ]) {
        expect(challenge.localToCloud.containsKey(localOnly), isFalse);
      }
      expect(challenge.requiredCloudForeignKeys, contains('challenge_def_id'));
      expect(challenge.localNaturalKey, <String>['user_id', 'type']);
      expect(challenge.cloudNaturalKey, <String>['user_id', 'challenge_id']);

      final SyncTableMapping streak = SyncTableRegistry.byLocalTable('streak')!;
      expect(streak.cloudNaturalKey, <String>['user_id', 'streak_type']);
    });
  });
}
