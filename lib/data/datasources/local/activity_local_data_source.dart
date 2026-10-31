import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/activity.dart';
import '../../models/activity_session_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `activity_session` table.
///
/// Activity sessions are local-only: they carry the sync metadata columns for
/// consistency with the rest of the schema, but this DAO deliberately emits no
/// outbox events and the table is not registered with the sync engine.
class ActivityLocalDataSource extends BaseLocalDataSource {
  ActivityLocalDataSource({required super.database})
    : super(logName: 'ActivityLocalDataSource');

  Future<int> insert(ActivitySession session) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = ActivitySessionModel.toMap(session);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        return txn.insert(ActivitySessionModel.table, values);
      });
    });
  }

  Future<void> update(ActivitySession session) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, session.id);
        if (existing == null) return;
        final Map<String, Object?> values = ActivitySessionModel.toMap(session);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'];
        values['created_at'] = values['created_at'] ?? existing['created_at'];
        values['updated_at'] = SyncableDao.nowMs();
        values['row_version'] = _version(existing) + 1;
        await txn.update(
          ActivitySessionModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[session.id],
        );
      });
    });
  }

  Future<ActivitySession?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ActivitySessionModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ActivitySessionModel.fromMap(rows.first);
    });
  }

  /// Recent sessions for [userId], newest first.
  ///
  /// `route_json` is excluded because list cards only need the aggregate
  /// metrics; the GPS trace can hold thousands of points. The detail screen
  /// loads the full row through [getById].
  Future<List<ActivitySession>> getByUserId(String userId, {int limit = 50}) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ActivitySessionModel.table,
        columns: <String>[
          'id',
          'user_id',
          'activity_type',
          'started_at',
          'ended_at',
          'duration_seconds',
          'distance_meters',
          'calories_burned',
          'elevation_gain_meters',
          'avg_speed_mps',
          'max_speed_mps',
          'note',
          'created_at',
        ],
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'started_at DESC',
        limit: limit,
      );
      return rows.map(ActivitySessionModel.fromMap).toList();
    });
  }

  Future<ActivityStats> getStats(String userId) {
    return guard('get_stats', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        '''
        SELECT
          COUNT(*) AS total_sessions,
          COALESCE(SUM(distance_meters), 0) AS total_distance,
          COALESCE(SUM(duration_seconds), 0) AS total_duration,
          COALESCE(SUM(calories_burned), 0) AS total_calories
        FROM ${ActivitySessionModel.table}
        WHERE user_id = ? AND deleted_at IS NULL
        ''',
        <Object?>[userId],
      );
      if (rows.isEmpty) return const ActivityStats();
      final Map<String, Object?> row = rows.first;
      return ActivityStats(
        totalSessions: (row['total_sessions'] as num?)?.toInt() ?? 0,
        totalDistanceMeters: (row['total_distance'] as num?)?.toDouble() ?? 0,
        totalDurationSeconds: (row['total_duration'] as num?)?.toInt() ?? 0,
        totalCalories: (row['total_calories'] as num?)?.toDouble() ?? 0,
      );
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        await txn.update(
          ActivitySessionModel.table,
          <String, Object?>{
            'deleted_at': now,
            'updated_at': now,
            'row_version': _version(existing) + 1,
          },
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
      });
    });
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      ActivitySessionModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
