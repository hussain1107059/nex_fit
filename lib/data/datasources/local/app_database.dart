import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';

/// A single versioned database migration.
class DatabaseMigration {
  const DatabaseMigration({required this.version, required this.apply});

  final int version;

  /// Applies the migration inside a transaction.
  final Future<void> Function(DatabaseExecutor executor, int version) apply;
}

/// SQFlite connection manager.
///
/// Owns the schema version and applies pending migrations on startup.
/// New tables are registered by appending [DatabaseMigration]s to the
/// [migrations] list during a future feature build.
class AppDatabase {
  AppDatabase({Logger? logger}) : _logger = logger ?? Logger('AppDatabase');

  final Logger _logger;

  static const String migrationsTable = 'schema_migrations';

  Database? _database;

  final List<DatabaseMigration> _migrations = const [
    DatabaseMigration(version: 1, apply: _migrationV1CreateUsers),
    DatabaseMigration(version: 2, apply: _migrationV2CreateDomainSchema),
    DatabaseMigration(version: 3, apply: _migrationV3AddProfileFields),
    DatabaseMigration(version: 4, apply: _migrationV4WorkoutModule),
    DatabaseMigration(version: 5, apply: _migrationV5ExerciseLibrary),
    DatabaseMigration(version: 6, apply: _migrationV6NutritionModule),
    DatabaseMigration(version: 7, apply: _migrationV7WaterModule),
    DatabaseMigration(version: 8, apply: _migrationV8WeightModule),
    DatabaseMigration(version: 9, apply: _migrationV9ReminderModule),
    DatabaseMigration(version: 10, apply: _migrationV10GamificationModule),
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _open();
    return _database!;
  }

  Future<String> get _databasePath async {
    // Web has no filesystem; the ffi web factory resolves the bare file
    // name against its IndexedDB-backed storage.
    if (kIsWeb) return AppConstants.databaseName;
    final String databasesPath = await getDatabasesPath();
    return path.join(databasesPath, AppConstants.databaseName);
  }

  Future<Database> _open() async {
    try {
      final Database db = await openDatabase(
        await _databasePath,
        version: AppConstants.databaseVersion,
        onConfigure: _onConfigure,
        onOpen: _onOpen,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      _logger.info('Database opened at version ${AppConstants.databaseVersion}');
      return db;
    } catch (error, stackTrace) {
      _logger.severe('Failed to open database: $error', error, stackTrace);
      throw const DatabaseException('errorDatabase');
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $migrationsTable (
        version INTEGER PRIMARY KEY NOT NULL
      )
    ''');
    // Baseline version 0 so every registered migration runs on fresh
    // installations.
    await db.insert(
      migrationsTable,
      {'version': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _onOpen(Database db) async {
    await _applyPendingMigrations(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _applyPendingMigrations(db);
  }

  Future<void> _applyPendingMigrations(Database db) async {
    final List<int> applied = await _appliedVersions(db);
    final List<DatabaseMigration> pending = _migrations
        .where((migration) => !applied.contains(migration.version))
        .toList()
      ..sort((a, b) => a.version.compareTo(b.version));

    if (pending.isEmpty) return;

    await db.transaction((txn) async {
      for (final DatabaseMigration migration in pending) {
        _logger.info('Applying migration version ${migration.version}');
        await migration.apply(txn, migration.version);
        await txn.insert(
          migrationsTable,
          {'version': migration.version},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<List<int>> _appliedVersions(Database db) async {
    final List<Map<String, Object?>> rows = await db.query(migrationsTable);
    return rows.map((row) => row['version'] as int).toList();
  }

  /// Runs a callback inside a database transaction.
  Future<T> inTransaction<T>(
    Future<T> Function(Transaction transaction) action,
  ) async {
    final Database db = await database;
    return db.transaction(action);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// v1: local user profiles created after signing in.
  static Future<void> _migrationV1CreateUsers(
    DatabaseExecutor executor,
    int version,
  ) async {
    await executor.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        photo TEXT,
        provider TEXT NOT NULL,
        created_at INTEGER,
        last_login INTEGER
      )
    ''');
  }

  /// v2: the complete offline-first fitness domain schema. Every feature
  /// table is keyed to `users(id)` so all personal data is per-account and
  /// cascade-deleted when the profile is removed. Reference/catalog tables
  /// (workout_category, meal_category, exercise) and seeded goal templates
  /// are global. Seeds use INSERT OR IGNORE so they survive re-runs.
  static Future<void> _migrationV2CreateDomainSchema(
    DatabaseExecutor executor,
    int version,
  ) async {
    final DatabaseExecutor db = executor;

    await db.execute('''
      CREATE TABLE user_profile (
        user_id TEXT PRIMARY KEY NOT NULL,
        height_cm REAL,
        weight_kg REAL,
        gender TEXT,
        birth_date INTEGER,
        activity_level TEXT,
        target_calories REAL,
        target_protein REAL,
        target_carbs REAL,
        target_fat REAL,
        target_water_ml INTEGER,
        target_steps INTEGER,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE fitness_goal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        title TEXT NOT NULL,
        description TEXT,
        goal_type TEXT NOT NULL,
        target_value REAL,
        current_value REAL NOT NULL DEFAULT 0,
        start_date INTEGER,
        target_date INTEGER,
        status TEXT NOT NULL DEFAULT 'active',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE (user_id, goal_type),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        slug TEXT NOT NULL UNIQUE,
        description TEXT,
        icon TEXT,
        color INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workout (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        category_id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        difficulty TEXT,
        duration_minutes INTEGER,
        calories_burn REAL,
        is_custom INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES workout_category(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        body_part TEXT,
        equipment TEXT,
        difficulty TEXT,
        image TEXT,
        calories_per_minute REAL,
        is_custom INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_exercise (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        sets INTEGER NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        rest_seconds INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (workout_id) REFERENCES workout(id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercise(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        workout_id INTEGER,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        duration_minutes INTEGER,
        calories_burn REAL,
        notes TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (workout_id) REFERENCES workout(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_history_id INTEGER NOT NULL,
        exercise_id INTEGER,
        sets INTEGER NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0,
        weight_kg REAL,
        duration_seconds INTEGER,
        completed_at INTEGER,
        FOREIGN KEY (workout_history_id) REFERENCES workout_history(id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercise(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        slug TEXT NOT NULL UNIQUE,
        icon TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE meal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        category_id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        calories REAL NOT NULL DEFAULT 0,
        protein REAL NOT NULL DEFAULT 0,
        carbs REAL NOT NULL DEFAULT 0,
        fat REAL NOT NULL DEFAULT 0,
        image TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES meal_category(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food_item (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        name TEXT NOT NULL,
        brand TEXT,
        category TEXT,
        serving_size TEXT,
        serving_grams REAL,
        calories REAL NOT NULL DEFAULT 0,
        protein REAL NOT NULL DEFAULT 0,
        carbs REAL NOT NULL DEFAULT 0,
        fat REAL NOT NULL DEFAULT 0,
        fiber REAL NOT NULL DEFAULT 0,
        sugar REAL NOT NULL DEFAULT 0,
        is_custom INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE food_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        food_item_id INTEGER,
        meal_id INTEGER,
        quantity REAL NOT NULL DEFAULT 1,
        serving_size TEXT,
        calories REAL NOT NULL DEFAULT 0,
        protein REAL NOT NULL DEFAULT 0,
        carbs REAL NOT NULL DEFAULT 0,
        fat REAL NOT NULL DEFAULT 0,
        logged_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (food_item_id) REFERENCES food_item(id) ON DELETE SET NULL,
        FOREIGN KEY (meal_id) REFERENCES meal(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE water_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        amount_ml INTEGER NOT NULL,
        logged_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE weight_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        note TEXT,
        logged_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE bmi_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        bmi REAL NOT NULL,
        weight_kg REAL,
        height_cm REAL,
        category TEXT,
        logged_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE body_measurement (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        chest_cm REAL,
        waist_cm REAL,
        hip_cm REAL,
        arm_cm REAL,
        thigh_cm REAL,
        neck_cm REAL,
        shoulder_cm REAL,
        note TEXT,
        measured_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE calorie_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        calories_consumed REAL NOT NULL DEFAULT 0,
        calories_burned REAL NOT NULL DEFAULT 0,
        net_calories REAL NOT NULL DEFAULT 0,
        logged_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sleep_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        sleep_date INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL,
        bedtime INTEGER,
        wake_time INTEGER,
        quality INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE step_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        step_date INTEGER NOT NULL,
        steps INTEGER NOT NULL DEFAULT 0,
        distance_km REAL NOT NULL DEFAULT 0,
        calories_burned REAL NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reminder (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT,
        reminder_type TEXT NOT NULL DEFAULT 'custom',
        time TEXT NOT NULL,
        days_of_week TEXT,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        last_triggered_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE achievement (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        achievement_type TEXT,
        icon TEXT,
        is_unlocked INTEGER NOT NULL DEFAULT 0,
        unlocked_at INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE badge (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        badge_type TEXT NOT NULL,
        badge_name TEXT NOT NULL,
        icon TEXT,
        level INTEGER NOT NULL DEFAULT 1,
        progress REAL NOT NULL DEFAULT 0,
        target REAL NOT NULL DEFAULT 0,
        is_earned INTEGER NOT NULL DEFAULT 0,
        earned_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE streak (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        streak_type TEXT NOT NULL,
        current_streak INTEGER NOT NULL DEFAULT 0,
        longest_streak INTEGER NOT NULL DEFAULT 0,
        last_active_date INTEGER,
        best_date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE (user_id, streak_type),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        progress_date INTEGER NOT NULL,
        steps INTEGER NOT NULL DEFAULT 0,
        water_ml INTEGER NOT NULL DEFAULT 0,
        calories_consumed REAL NOT NULL DEFAULT 0,
        calories_burned REAL NOT NULL DEFAULT 0,
        workout_minutes INTEGER NOT NULL DEFAULT 0,
        sleep_minutes INTEGER NOT NULL DEFAULT 0,
        weight_kg REAL,
        is_goal_met INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE (user_id, progress_date),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL UNIQUE,
        theme TEXT,
        locale TEXT,
        units TEXT NOT NULL DEFAULT 'metric',
        daily_calorie_target REAL,
        daily_water_target_ml INTEGER,
        daily_step_target INTEGER,
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        reminder_enabled INTEGER NOT NULL DEFAULT 1,
        data_sync_enabled INTEGER NOT NULL DEFAULT 1,
        backup_enabled INTEGER NOT NULL DEFAULT 1,
        last_backup_at INTEGER,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE backup_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        backup_type TEXT NOT NULL,
        backup_size_bytes INTEGER,
        file_name TEXT,
        file_id TEXT,
        status TEXT NOT NULL,
        error_message TEXT,
        duration_ms INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);

    await _insertSeedData(db);
  }

  static Future<void> _createIndexes(DatabaseExecutor db) async {
    const Map<String, String> indexes = <String, String>{
      'idx_fitness_goal_user_id': 'fitness_goal(user_id)',
      'idx_workout_user_id': 'workout(user_id)',
      'idx_workout_category_id': 'workout(category_id)',
      'idx_exercise_user_id': 'exercise(user_id)',
      'idx_workout_exercise_workout_id': 'workout_exercise(workout_id)',
      'idx_workout_exercise_exercise_id': 'workout_exercise(exercise_id)',
      'idx_workout_history_user_id': 'workout_history(user_id)',
      'idx_workout_history_started_at': 'workout_history(started_at)',
      'idx_exercise_history_workout_history_id':
          'exercise_history(workout_history_id)',
      'idx_meal_user_id': 'meal(user_id)',
      'idx_food_item_user_id': 'food_item(user_id)',
      'idx_food_log_user_id': 'food_log(user_id)',
      'idx_food_log_logged_at': 'food_log(logged_at)',
      'idx_water_log_user_id': 'water_log(user_id)',
      'idx_water_log_logged_at': 'water_log(logged_at)',
      'idx_weight_log_user_id': 'weight_log(user_id)',
      'idx_weight_log_logged_at': 'weight_log(logged_at)',
      'idx_bmi_log_user_id': 'bmi_log(user_id)',
      'idx_body_measurement_user_id': 'body_measurement(user_id)',
      'idx_calorie_log_user_id': 'calorie_log(user_id)',
      'idx_calorie_log_logged_at': 'calorie_log(logged_at)',
      'idx_sleep_log_user_id': 'sleep_log(user_id)',
      'idx_step_log_user_id': 'step_log(user_id)',
      'idx_step_log_step_date': 'step_log(step_date)',
      'idx_reminder_user_id': 'reminder(user_id)',
      'idx_achievement_user_id': 'achievement(user_id)',
      'idx_badge_user_id': 'badge(user_id)',
      'idx_daily_progress_user_id': 'daily_progress(user_id)',
      'idx_daily_progress_date': 'daily_progress(progress_date)',
      'idx_backup_history_user_id': 'backup_history(user_id)',
    };

    for (final MapEntry<String, String> entry in indexes.entries) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS ${entry.key} ON ${entry.value}',
      );
    }
  }

  static Future<void> _insertSeedData(DatabaseExecutor db) async {
    final int now = DateTime.now().millisecondsSinceEpoch;

    await db.execute('''
      INSERT OR IGNORE INTO workout_category (name, slug, description, sort_order, created_at)
      VALUES
        ('Home Workout', 'home_workout', NULL, 1, $now),
        ('Gym Workout', 'gym_workout', NULL, 2, $now),
        ('Cardio', 'cardio', NULL, 3, $now),
        ('Yoga', 'yoga', NULL, 4, $now),
        ('Strength', 'strength', NULL, 5, $now),
        ('HIIT', 'hiit', NULL, 6, $now),
        ('Stretching', 'stretching', NULL, 7, $now)
    ''');

    await db.execute('''
      INSERT OR IGNORE INTO meal_category (name, slug, sort_order, created_at)
      VALUES
        ('Breakfast', 'breakfast', 1, $now),
        ('Lunch', 'lunch', 2, $now),
        ('Dinner', 'dinner', 3, $now),
        ('Snacks', 'snacks', 4, $now)
    ''');

    await db.execute('''
      INSERT OR IGNORE INTO fitness_goal (title, description, goal_type, status, created_at, updated_at)
      VALUES
        ('Weight Loss', 'Gradually lose body weight', 'weight_loss', 'active', $now, $now),
        ('Weight Gain', 'Gain healthy body weight', 'weight_gain', 'active', $now, $now),
        ('Maintain Weight', 'Keep current body weight stable', 'maintain_weight', 'active', $now, $now),
        ('Muscle Building', 'Build lean muscle mass', 'muscle_building', 'active', $now, $now)
    ''');
  }

  /// v3: extends `user_profile` with the premium profile fields used by the
  /// profile module (target weight, fitness goal, locale, country and the
  /// local profile photo path). All new columns are nullable so the upgrade
  /// is safe for existing rows; ALTER TABLE ADD COLUMN cannot add a NOT NULL
  /// column without a default value in SQLite.
  static Future<void> _migrationV3AddProfileFields(
    DatabaseExecutor executor,
    int version,
  ) async {
    final DatabaseExecutor db = executor;

    await db.execute(
      'ALTER TABLE user_profile ADD COLUMN target_weight_kg REAL',
    );
    await db.execute('ALTER TABLE user_profile ADD COLUMN fitness_goal TEXT');
    await db.execute('ALTER TABLE user_profile ADD COLUMN country TEXT');
    await db.execute('ALTER TABLE user_profile ADD COLUMN language TEXT');
    await db.execute('ALTER TABLE user_profile ADD COLUMN photo_path TEXT');
  }

  /// v4: extends the workout domain for the complete workout module.
  ///
  /// * `workout.image` - optional cover image for a routine.
  /// * `workout.is_favorite` - locally stored favourite flag.
  /// * `exercise.instructions` - step-by-step coaching text.
  ///
  /// It also expands the global `workout_category` catalog from 7 to the full
  /// 21 categories used across the module, attaching an icon key and a brand
  /// colour to every entry (existing rows are updated in place by slug).
  static Future<void> _migrationV4WorkoutModule(
    DatabaseExecutor executor,
    int version,
  ) async {
    final DatabaseExecutor db = executor;

    await db.execute('ALTER TABLE workout ADD COLUMN image TEXT');
    await db.execute(
      'ALTER TABLE workout ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE exercise ADD COLUMN instructions TEXT');

    final int now = DateTime.now().millisecondsSinceEpoch;

    // New categories (INSERT OR IGNORE by unique slug).
    await db.execute('''
      INSERT OR IGNORE INTO workout_category
        (name, slug, description, icon, color, sort_order, created_at)
      VALUES
        ('Full Body', 'full_body', 'Train every major muscle group in one session', 'full_body', 4279148398, 8, $now),
        ('Upper Body', 'upper_body', 'Focus on arms, chest, back and shoulders', 'upper_body', 4282090230, 9, $now),
        ('Lower Body', 'lower_body', 'Build strong legs, glutes and core', 'lower_body', 4294286859, 10, $now),
        ('Chest', 'chest', 'Build a stronger, bigger chest', 'chest', 4293870660, 11, $now),
        ('Back', 'back', 'Strengthen your back and posture', 'back', 4284704497, 12, $now),
        ('Shoulder', 'shoulder', 'Sculpt strong, defined shoulders', 'shoulder', 4282090230, 13, $now),
        ('Arms', 'arms', 'Biceps, triceps and forearm strength', 'arms', 4294538006, 14, $now),
        ('Legs', 'legs', 'Powerful legs with squats and lunges', 'legs', 4287323382, 15, $now),
        ('Core', 'core', 'Strengthen your abs and core stability', 'core', 4293675161, 16, $now),
        ('Fat Loss', 'fat_loss', 'Burn fat with calorie-torching sessions', 'fat_loss', 4294286859, 17, $now),
        ('Muscle Gain', 'muscle_gain', 'Hypertrophy training to build muscle', 'muscle_gain', 4280468830, 18, $now),
        ('Beginner', 'beginner', 'Easy, beginner-friendly workouts', 'beginner', 4279548070, 19, $now),
        ('Intermediate', 'intermediate', 'Moderate workouts for steady progress', 'intermediate', 4282090230, 20, $now),
        ('Advanced', 'advanced', 'Challenging workouts for experienced athletes', 'advanced', 4287323382, 21, $now)
    ''');

    // Refresh metadata (icon, colour, description) for every category,
    // including the seven seeded in v2.
    await db.execute('''
      UPDATE workout_category SET
        description = 'Work out at home with minimal equipment',
        icon = 'home', color = 4279148398
      WHERE slug = 'home_workout'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        description = 'Use gym equipment for full training sessions',
        icon = 'gym', color = 4285357008
      WHERE slug = 'gym_workout'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        description = 'Get your heart pumping and burn calories',
        icon = 'cardio', color = 4293870660
      WHERE slug = 'cardio'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        description = 'Improve flexibility, balance and mindfulness',
        icon = 'yoga', color = 4287323382
      WHERE slug = 'yoga'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        description = 'Build strength with resistance training',
        icon = 'strength', color = 4294538006
      WHERE slug = 'strength'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        description = 'High intensity interval training for quick results',
        icon = 'hiit', color = 4294937088
      WHERE slug = 'hiit'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        description = 'Improve mobility and recover faster',
        icon = 'stretching', color = 4279548070
      WHERE slug = 'stretching'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'full_body', color = 4279148398
      WHERE slug = 'full_body'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'upper_body', color = 4282090230
      WHERE slug = 'upper_body'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'lower_body', color = 4294286859
      WHERE slug = 'lower_body'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'chest', color = 4293870660
      WHERE slug = 'chest'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'back', color = 4284704497
      WHERE slug = 'back'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'shoulder', color = 4282090230
      WHERE slug = 'shoulder'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'arms', color = 4294538006
      WHERE slug = 'arms'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'legs', color = 4287323382
      WHERE slug = 'legs'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'core', color = 4293675161
      WHERE slug = 'core'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'fat_loss', color = 4294286859
      WHERE slug = 'fat_loss'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'muscle_gain', color = 4280468830
      WHERE slug = 'muscle_gain'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'beginner', color = 4279548070
      WHERE slug = 'beginner'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'intermediate', color = 4282090230
      WHERE slug = 'intermediate'
    ''');
    await db.execute('''
      UPDATE workout_category SET
        icon = 'advanced', color = 4287323382
      WHERE slug = 'advanced'
    ''');
  }

  /// v5: the complete exercise library module.
  ///
  /// Enriches the global `exercise` catalog with the full coaching payload
  /// (scientific name, category, target/secondary muscles, suggested program,
  /// tips, common mistakes and safety instructions) and adds the per-user
  /// `exercise_favorite` join table so favourite flags live with each account
  /// instead of mutating the shared catalog. All new columns are nullable or
  /// defaulted so the upgrade is safe for existing rows; the seeder back-fills
  /// the rich fields on the next launch.
  static Future<void> _migrationV5ExerciseLibrary(
    DatabaseExecutor executor,
    int version,
  ) async {
    final DatabaseExecutor db = executor;

    await db.execute('ALTER TABLE exercise ADD COLUMN scientific_name TEXT');
    await db.execute('ALTER TABLE exercise ADD COLUMN gif_path TEXT');
    await db.execute('ALTER TABLE exercise ADD COLUMN category TEXT');
    await db.execute('ALTER TABLE exercise ADD COLUMN target_muscle TEXT');
    await db.execute('ALTER TABLE exercise ADD COLUMN secondary_muscle TEXT');
    await db.execute('ALTER TABLE exercise ADD COLUMN estimated_calories REAL');
    await db.execute(
      'ALTER TABLE exercise ADD COLUMN duration_seconds INTEGER NOT NULL DEFAULT 30',
    );
    await db.execute(
      'ALTER TABLE exercise ADD COLUMN sets INTEGER NOT NULL DEFAULT 3',
    );
    await db.execute(
      'ALTER TABLE exercise ADD COLUMN reps INTEGER NOT NULL DEFAULT 12',
    );
    await db.execute(
      'ALTER TABLE exercise ADD COLUMN rest_seconds INTEGER NOT NULL DEFAULT 30',
    );
    await db.execute('ALTER TABLE exercise ADD COLUMN tips TEXT');
    await db.execute('ALTER TABLE exercise ADD COLUMN common_mistakes TEXT');
    await db.execute('ALTER TABLE exercise ADD COLUMN safety_instructions TEXT');

    await db.execute('''
      CREATE TABLE exercise_favorite (
        user_id TEXT NOT NULL,
        exercise_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, exercise_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercise(id) ON DELETE CASCADE
      )
    ''');
  }

  /// v6: the nutrition & calorie tracker module.
  ///
  /// * `food_item` gains the micronutrient/meta columns required by the food
  ///   database (sodium, potassium, calcium, iron, vitamin A/C, water %, plus
  ///   optional barcode and image). All nullable so existing rows stay valid.
  /// * `food_log` snapshots fiber and sugar (alongside the existing macros)
  ///   and links each entry to a meal slot via `meal_type_id`.
  /// * New per-user `food_favorite` join table for the favourites collection.
  /// * New `meal_item` join table so saved meal templates can reference foods.
  /// * The global `meal_category` catalog grows from 4 to the 6 meal slots
  ///   (Breakfast, Morning Snack, Lunch, Evening Snack, Dinner, Late Night
  ///   Snack); the old `snacks` row is renamed in place to keep ids stable.
  static Future<void> _migrationV6NutritionModule(
    DatabaseExecutor executor,
    int version,
  ) async {
    final DatabaseExecutor db = executor;

    await db.execute('ALTER TABLE food_item ADD COLUMN sodium REAL');
    await db.execute('ALTER TABLE food_item ADD COLUMN potassium REAL');
    await db.execute('ALTER TABLE food_item ADD COLUMN calcium REAL');
    await db.execute('ALTER TABLE food_item ADD COLUMN iron REAL');
    await db.execute('ALTER TABLE food_item ADD COLUMN vitamin_a REAL');
    await db.execute('ALTER TABLE food_item ADD COLUMN vitamin_c REAL');
    await db.execute(
      'ALTER TABLE food_item ADD COLUMN water_percentage REAL',
    );
    await db.execute('ALTER TABLE food_item ADD COLUMN barcode TEXT');
    await db.execute('ALTER TABLE food_item ADD COLUMN image_path TEXT');

    await db.execute(
      'ALTER TABLE food_log ADD COLUMN fiber REAL NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE food_log ADD COLUMN sugar REAL NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE food_log ADD COLUMN meal_type_id INTEGER');

    await db.execute('''
      CREATE TABLE food_favorite (
        user_id TEXT NOT NULL,
        food_item_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, food_item_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (food_item_id) REFERENCES food_item(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_item (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id INTEGER NOT NULL,
        food_item_id INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (meal_id) REFERENCES meal(id) ON DELETE CASCADE,
        FOREIGN KEY (food_item_id) REFERENCES food_item(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_food_favorite_user_id '
      'ON food_favorite(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_meal_item_meal_id ON meal_item(meal_id)',
    );

    final int now = DateTime.now().millisecondsSinceEpoch;

    // Rename the generic Snacks slot to the evening snack, keeping its id.
    await db.execute('''
      UPDATE meal_category SET
        name = 'Evening Snack',
        slug = 'evening_snack',
        sort_order = 4
      WHERE slug = 'snacks'
    ''');

    // Add the two new slots and normalise the ordering of the full catalog.
    await db.execute('''
      INSERT OR IGNORE INTO meal_category (name, slug, sort_order, created_at)
      VALUES
        ('Morning Snack', 'morning_snack', 2, $now),
        ('Late Night Snack', 'late_night_snack', 6, $now)
    ''');

    await db.execute('''
      UPDATE meal_category SET sort_order = 1 WHERE slug = 'breakfast'
    ''');
    await db.execute('''
      UPDATE meal_category SET sort_order = 3 WHERE slug = 'lunch'
    ''');
    await db.execute('''
      UPDATE meal_category SET sort_order = 5 WHERE slug = 'dinner'
    ''');
  }

  /// v7: the water tracker & hydration module.
  ///
  /// The core `water_log`, `reminder` and `user_profile.target_water_ml`
  /// tables already existed from v2; this migration only extends the water
  /// log with an optional free-text note so custom entries can be annotated.
  /// The column is nullable so the upgrade is safe for existing rows.
  static Future<void> _migrationV7WaterModule(
    DatabaseExecutor executor,
    int version,
  ) async {
    final DatabaseExecutor db = executor;
    await db.execute('ALTER TABLE water_log ADD COLUMN note TEXT');
  }

  /// v8: the weight tracker & body measurement module.
  ///
  /// The core `weight_log`, `bmi_log` and `body_measurement` tables already
  /// existed from v2; this migration expands `body_measurement` with the full
  /// left/right limb set (left/right arm, left/right thigh, left/right calf)
  /// used by the body measurement tracker. Every new column is nullable so the
  /// upgrade is safe for existing rows.
  static Future<void> _migrationV8WeightModule(
    DatabaseExecutor executor,
    int version,
  ) async {
    final DatabaseExecutor db = executor;

    await db.execute('ALTER TABLE body_measurement ADD COLUMN left_arm_cm REAL');
    await db.execute('ALTER TABLE body_measurement ADD COLUMN right_arm_cm REAL');
    await db.execute(
      'ALTER TABLE body_measurement ADD COLUMN left_thigh_cm REAL',
    );
    await db.execute(
      'ALTER TABLE body_measurement ADD COLUMN right_thigh_cm REAL',
    );
    await db.execute(
      'ALTER TABLE body_measurement ADD COLUMN left_calf_cm REAL',
    );
    await db.execute(
      'ALTER TABLE body_measurement ADD COLUMN right_calf_cm REAL',
    );
  }

  /// v9: the complete reminder & local notification module.
  ///
  /// Expands the v2 `reminder` table with the full scheduling/settings payload
  /// (schedule type, multiple times per day, one-time / monthly dates, icon,
  /// colour, sound / vibration / silent mode, action buttons and the related
  /// screen opened on tap) and adds the per-account `reminder_history` table
  /// used to record completed / missed / skipped occurrences for statistics.
  ///
  /// Every new column is nullable or defaulted so the upgrade is safe for
  /// existing rows; existing daily reminders keep firing unchanged.
  static Future<void> _migrationV9ReminderModule(
    DatabaseExecutor executor,
    int version,
  ) async {
    final DatabaseExecutor db = executor;

    await db.execute(
      'ALTER TABLE reminder ADD COLUMN schedule_type TEXT NOT NULL '
      "DEFAULT 'daily'",
    );
    await db.execute('ALTER TABLE reminder ADD COLUMN times TEXT');
    await db.execute('ALTER TABLE reminder ADD COLUMN start_date INTEGER');
    await db.execute('ALTER TABLE reminder ADD COLUMN end_date INTEGER');
    await db.execute('ALTER TABLE reminder ADD COLUMN month_day INTEGER');
    await db.execute('ALTER TABLE reminder ADD COLUMN icon TEXT');
    await db.execute('ALTER TABLE reminder ADD COLUMN color_value INTEGER');
    await db.execute(
      'ALTER TABLE reminder ADD COLUMN sound_enabled INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      'ALTER TABLE reminder ADD COLUMN vibration_enabled INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      'ALTER TABLE reminder ADD COLUMN silent_mode INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE reminder ADD COLUMN show_action_buttons INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute('ALTER TABLE reminder ADD COLUMN related_screen TEXT');

    await db.execute('''
      CREATE TABLE reminder_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        reminder_id INTEGER,
        status TEXT NOT NULL DEFAULT 'missed',
        scheduled_for INTEGER NOT NULL,
        acted_at INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (reminder_id) REFERENCES reminder(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminder_history_user_id '
      'ON reminder_history(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminder_history_reminder_id '
      'ON reminder_history(reminder_id)',
    );
  }

  /// v10: the offline gamification progression layer.
  static Future<void> _migrationV10GamificationModule(
    DatabaseExecutor executor,
    int version,
  ) async {
    final DatabaseExecutor db = executor;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS xp_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        source TEXT NOT NULL,
        reason TEXT NOT NULL,
        xp INTEGER NOT NULL DEFAULT 0,
        total_xp INTEGER NOT NULL DEFAULT 0,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_level (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        level INTEGER NOT NULL DEFAULT 1,
        current_xp INTEGER NOT NULL DEFAULT 0,
        required_xp INTEGER NOT NULL DEFAULT 100,
        total_xp INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE (user_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS challenge (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        difficulty TEXT NOT NULL DEFAULT 'medium',
        target INTEGER NOT NULL DEFAULT 0,
        progress INTEGER NOT NULL DEFAULT 0,
        reward_xp INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE (user_id, type),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS milestone (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        challenge_id INTEGER,
        title TEXT NOT NULL,
        target_value INTEGER NOT NULL DEFAULT 0,
        current_value INTEGER NOT NULL DEFAULT 0,
        is_reached INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (challenge_id) REFERENCES challenge(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reward (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        icon TEXT,
        is_claimed INTEGER NOT NULL DEFAULT 0,
        claimed_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE (user_id, type, title),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_achievement_user_type
      ON achievement (user_id, achievement_type)
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_badge_user_type
      ON badge (user_id, badge_type)
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_xp_history_user_source_reason
      ON xp_history (user_id, source, reason)
    ''');
  }
}
