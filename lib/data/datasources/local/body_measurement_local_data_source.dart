import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/body_measurement.dart';
import '../../models/body_measurement_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `body_measurement` table.
///
/// Sync-aware (PROMPT 13 Batch 3): every mutation runs inside a transaction
/// together with its outbox event. Reads always target a single row or a
/// bounded date/user range.
class BodyMeasurementLocalDataSource extends BaseLocalDataSource {
  BodyMeasurementLocalDataSource({required super.database})
    : super(logName: 'BodyMeasurementLocalDataSource');

  Future<int> insert(BodyMeasurement measurement) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values =
            BodyMeasurementModel.toMap(measurement);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id =
            await txn.insert(BodyMeasurementModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: BodyMeasurementModel.table,
          entityId: '$id',
          userId: measurement.userId,
        );
        return id;
      });
    });
  }

  /// Inserts many measurements in a single transaction (never loads the table
  /// into memory); each row gets its own uuid and CREATE outbox event.
  Future<void> insertAll(List<BodyMeasurement> measurements) {
    return guard('insert_all', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        for (final BodyMeasurement measurement in measurements) {
          final Map<String, Object?> values =
              BodyMeasurementModel.toMap(measurement);
          values['uuid'] = SyncableDao.newUuid();
          values['created_at'] = values['created_at'] ?? now;
          values['updated_at'] = now;
          values['row_version'] = SyncableDao.firstRowVersion;
          final int id =
              await txn.insert(BodyMeasurementModel.table, values);
          await SyncableDao.recordCreate(
            txn,
            entity: BodyMeasurementModel.table,
            entityId: '$id',
            userId: measurement.userId,
          );
        }
      });
    });
  }

  Future<void> update(BodyMeasurement measurement) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing =
            await _findRow(txn, measurement.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values =
            BodyMeasurementModel.toMap(measurement);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String;
        values['created_at'] =
            values['created_at'] ?? existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          BodyMeasurementModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[measurement.id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: BodyMeasurementModel.table,
          entityId: '${measurement.id}',
          userId: measurement.userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<BodyMeasurement?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BodyMeasurementModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return BodyMeasurementModel.fromMap(rows.first);
    });
  }

  Future<List<BodyMeasurement>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BodyMeasurementModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'measured_at DESC',
      );
      return rows.map(BodyMeasurementModel.fromMap).toList();
    });
  }

  Future<List<BodyMeasurement>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return guard('get_by_date_range', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BodyMeasurementModel.table,
        where:
            'user_id = ? AND deleted_at IS NULL AND measured_at >= ? AND measured_at < ?',
        whereArgs: <Object?>[
          userId,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'measured_at DESC',
      );
      return rows.map(BodyMeasurementModel.fromMap).toList();
    });
  }

  Future<BodyMeasurement?> getLatest(String userId) {
    return guard('get_latest', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BodyMeasurementModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'measured_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return BodyMeasurementModel.fromMap(rows.first);
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await txn.update(
          BodyMeasurementModel.table,
          <String, Object?>{
            'deleted_at': now,
            'updated_at': now,
            'row_version': baseVersion + 1,
          },
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        await SyncableDao.recordDelete(
          txn,
          entity: BodyMeasurementModel.table,
          entityId: '$id',
          userId: existing['user_id'] as String,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      BodyMeasurementModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}
