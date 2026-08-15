import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/exercise_history_local_data_source.dart';
import 'package:nexfit/data/datasources/local/user_profile_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_category_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_exercise_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_history_local_data_source.dart';
import 'package:nexfit/data/datasources/local/workout_local_data_source.dart';
import 'package:nexfit/data/repositories/exercise_history_repository_impl.dart';
import 'package:nexfit/data/repositories/user_fitness_profile_repository_impl.dart';
import 'package:nexfit/data/repositories/workout_category_repository_impl.dart';
import 'package:nexfit/data/repositories/workout_exercise_repository_impl.dart';
import 'package:nexfit/data/repositories/workout_history_repository_impl.dart';
import 'package:nexfit/data/repositories/workout_library_repository_impl.dart';
import 'package:nexfit/data/repositories/workout_repository_impl.dart';
import 'package:nexfit/data/services/workout_seeder.dart';
import 'package:nexfit/domain/entities/workout.dart';
import 'package:nexfit/domain/entities/workout_detail.dart';
import 'package:nexfit/domain/entities/workout_filter.dart';
import 'package:nexfit/domain/entities/workout_library.dart';

/// PROMPT 29 — Workout experience finalization.
///
/// The equipment filter options are now aligned with the real seeded catalog
/// (previously the picker listed 8 English names — "Barbell", "Kettlebell",
/// "Resistance Band", "Yoga Mat", "Treadmill", "Exercise Ball" — that never
/// match any seeded workout, so filtering by them returned nothing). The
/// routine tiles, the instructions chip and the empty-library CTA all rely on
/// data that is guaranteed present for the seeded library.
///
/// See `docs/NEXFIT_DAO_SYNC_MIGRATION_PLAN.md` §25.

class _Harness {
  _Harness(this.db);

  final AppDatabase db;

  late final WorkoutLibraryRepositoryImpl library;

  Future<void> init() async {
    final raw = await db.database;
    await raw.insert('users', <String, Object?>{
      'id': 'u-1',
      'name': 'Rahim',
      'email': 'rahim@example.com',
      'provider': 'email',
    });

    final workoutCategory = WorkoutCategoryRepositoryImpl(
      WorkoutCategoryLocalDataSource(database: db),
    );
    final workout = WorkoutRepositoryImpl(
      WorkoutLocalDataSource(database: db),
    );
    final workoutExercise = WorkoutExerciseRepositoryImpl(
      WorkoutExerciseLocalDataSource(database: db),
    );
    final history = WorkoutHistoryRepositoryImpl(
      WorkoutHistoryLocalDataSource(database: db),
    );
    final exerciseHistory = ExerciseHistoryRepositoryImpl(
      ExerciseHistoryLocalDataSource(database: db),
    );
    final profile = UserFitnessProfileRepositoryImpl(
      UserProfileLocalDataSource(database: db),
    );
    final WorkoutSeeder seeder = WorkoutSeeder(database: db);

    library = WorkoutLibraryRepositoryImpl(
      workoutRepository: workout,
      categoryRepository: workoutCategory,
      historyRepository: history,
      workoutExerciseRepository: workoutExercise,
      exerciseHistoryRepository: exerciseHistory,
      userProfileRepository: profile,
      seeder: seeder,
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
      '${await databaseFactory.getDatabasesPath()}/workout_finalization.db',
    );
    harness = _Harness(AppDatabase(databaseName: 'workout_finalization.db'));
    await harness.init();
  });

  tearDown(() async {
    await harness.close();
  });

  group('PROMPT 29 workout finalization', () {
    test('equipment filter matches the seeded catalog values', () async {
      final WorkoutLibraryData data = await harness.library.loadLibrary('u-1');
      expect(data.recommended, isNotEmpty);

      final List<Workout> dumbbell = await harness.library.search(
        'u-1',
        const WorkoutFilter(equipment: 'Dumbbell'),
      );
      expect(dumbbell, isNotEmpty,
          reason: 'Dumbbell is a real seeded equipment value');

      final List<Workout> legacy = await harness.library.search(
        'u-1',
        const WorkoutFilter(equipment: 'Barbell'),
      );
      expect(legacy, isEmpty,
          reason: 'Barbell never appears in the seeded catalog, so the old '
              'picker value matched nothing');
    });

    test('workout detail exposes every routine exercise with an id', () async {
      await harness.library.ensureSeeded('u-1');
      final WorkoutLibraryData data = await harness.library.loadLibrary('u-1');
      final Workout any = data.recommended.first;

      final WorkoutDetail detail = await harness.library.getDetail(any.id!);

      expect(detail.exercises, isNotEmpty);
      for (final exercise in detail.exercises) {
        expect(exercise.exercise.id, isNotNull,
            reason: 'the routine tile navigates to exerciseDetailPath(id)');
      }
    });

    test('seeded exercises carry instructions for the player chip', () async {
      await harness.library.ensureSeeded('u-1');
      final WorkoutLibraryData data = await harness.library.loadLibrary('u-1');

      final WorkoutDetail detail = await harness.library.getDetail(
        data.recommended.first.id!,
      );

      expect(
        detail.exercises.any(
          (final exercise) =>
              exercise.exercise.instructions != null &&
              exercise.exercise.instructions!.trim().isNotEmpty,
        ),
        isTrue,
        reason: 'the player "How to" chip only renders for real instructions',
      );
    });

    test('seeding is idempotent and never leaves an empty library', () async {
      await harness.library.ensureSeeded('u-1');
      await harness.library.ensureSeeded('u-1');

      final WorkoutLibraryData data = await harness.library.loadLibrary('u-1');

      expect(data.categories, isNotEmpty);
      expect(data.recommended, isNotEmpty);
    });

    test('search without filters still returns the seeded library', () async {
      final List<Workout> all = await harness.library.search(
        'u-1',
        const WorkoutFilter(),
      );

      expect(all.length, greaterThanOrEqualTo(26),
          reason: 'the per-user seed provisions 26 default routines');
    });
  });
}