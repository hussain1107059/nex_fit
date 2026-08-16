import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexfit/data/datasources/local/app_database.dart';

/// PROMPT 37 — Performance audit: EXPLAIN QUERY PLAN evidence.
///
/// Every important query below is verified against the real planner on the
/// production schema (all 18 migrations). The goal is evidence for the audit:
/// the hot dashboard date-range reads, the outbox drain, the seed guards and
/// the LIKE searches must either be served by an existing index or be
/// documented as inherently unscannable. No index is added here without one of
/// these checks proving it would help.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;

  setUp(() async {
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/performance_audit.db',
    );
    db = AppDatabase(databaseName: 'performance_audit.db');
    await db.database;
  });

  tearDown(() => db.close());

  Future<String> plan(String sql) async {
    final Database raw = await db.database;
    final List<Map<String, Object?>> rows = await raw.rawQuery(
      'EXPLAIN QUERY PLAN $sql',
    );
    return rows.map((Map<String, Object?> r) => r['detail']).join(' | ');
  }

  String ts(int ms) => ms.toString();

  group('PROMPT 37 EXPLAIN QUERY PLAN', () {
    test('dashboard 7-day date-range reads are served by the '
        '(user_id, timestamp) composite indexes', () async {
      final int from = DateTime(2026, 6, 1).millisecondsSinceEpoch;
      final int to = DateTime(2026, 6, 8).millisecondsSinceEpoch;

      final Map<String, String> expected = <String, String>{
        "SELECT id FROM workout_history WHERE user_id = 'u-1' AND "
            'started_at >= ${ts(from)} AND started_at < ${ts(to)} AND '
            "deleted_at IS NULL": 'idx_workout_history_user_started',
        "SELECT id FROM water_log WHERE user_id = 'u-1' AND "
            'logged_at >= ${ts(from)} AND logged_at < ${ts(to)} AND '
            "deleted_at IS NULL": 'idx_water_log_user_logged',
        "SELECT id FROM weight_log WHERE user_id = 'u-1' AND "
            'logged_at >= ${ts(from)} AND logged_at < ${ts(to)} AND '
            "deleted_at IS NULL": 'idx_weight_log_user_logged',
        "SELECT id FROM sleep_log WHERE user_id = 'u-1' AND "
            'sleep_date >= ${ts(from)} AND sleep_date < ${ts(to)} AND '
            "deleted_at IS NULL": 'idx_sleep_log_user_date',
        "SELECT id FROM step_log WHERE user_id = 'u-1' AND "
            'step_date >= ${ts(from)} AND step_date < ${ts(to)} AND '
            "deleted_at IS NULL": 'idx_step_log_user_date',
        "SELECT id FROM food_log WHERE user_id = 'u-1' AND "
            'logged_at >= ${ts(from)} AND logged_at < ${ts(to)} AND '
            "deleted_at IS NULL": 'idx_food_log_user_logged',
      };

      for (final MapEntry<String, String> entry in expected.entries) {
        final String detail = await plan(entry.key);
        expect(detail, contains(entry.value),
            reason: '${entry.key}\nmust use ${entry.value}, got:\n$detail');
      }
    });

    test('the outbox drain is served by (user_id, status, created_at)',
        () async {
      final String detail = await plan(
        "SELECT id FROM sync_event WHERE user_id = 'u-1' "
        "AND status IN ('pending','failedRetryable') "
        'ORDER BY created_at ASC, id ASC LIMIT 500',
      );
      expect(detail, contains('idx_sync_event_user_status'));
    });

    test('uuid lookups are served by the per-table unique index', () async {
      final String detail = await plan(
        "SELECT id FROM workout_history WHERE uuid = 'x'",
      );
      expect(detail, contains('idx_workout_history_uuid'));
    });

    test('getEnabled reminder reads are served by (user_id, is_enabled)',
        () async {
      final String detail = await plan(
        "SELECT id FROM reminder WHERE user_id = 'u-1' "
        'AND is_enabled = 1 AND deleted_at IS NULL',
      );
      expect(detail, contains('idx_reminder_user_enabled'));
    });

    test('the seeder guard count on built-in exercises is index-served',
        () async {
      final String detail = await plan(
        'SELECT COUNT(*) AS count FROM exercise WHERE user_id IS NULL',
      );
      expect(
        detail,
        anyOf(contains('idx_exercise_user_id'), contains('idx_exercise_user_updated')),
        reason: 'served by an index, never a table scan:\n$detail',
      );
    });

    test('LIKE search is a documented scan (leading wildcard), so no index '
        'is warranted', () async {
      // `%query%` with a leading wildcard can never use a B-tree index; the
      // correct mitigations are the keystroke debounce (added) and the small
      // catalogs themselves. Asserting the scan here documents why no index
      // was added without evidence.
      final String foodDetail = await plan(
        "SELECT id FROM food_item WHERE LOWER(name) LIKE '%chicken%'",
      );
      expect(foodDetail, contains('SCAN food_item'));

      final String exerciseDetail = await plan(
        "SELECT id FROM exercise WHERE LOWER(name) LIKE '%press%'",
      );
      expect(exerciseDetail, contains('SCAN exercise'));
    });
  });
}