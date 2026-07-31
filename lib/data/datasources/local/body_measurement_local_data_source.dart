import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/body_measurement.dart';
import '../../models/body_measurement_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `body_measurement` table.
class BodyMeasurementLocalDataSource extends BaseLocalDataSource {
  BodyMeasurementLocalDataSource({required super.database})
    : super(logName: 'BodyMeasurementLocalDataSource');

  Future<int> insert(BodyMeasurement measurement) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        BodyMeasurementModel.table,
        BodyMeasurementModel.toMap(measurement),
      );
    });
  }

  Future<void> update(BodyMeasurement measurement) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        BodyMeasurementModel.table,
        BodyMeasurementModel.toMap(measurement),
        where: 'id = ?',
        whereArgs: <Object?>[measurement.id],
      );
    });
  }

  Future<BodyMeasurement?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        BodyMeasurementModel.table,
        where: 'id = ?',
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
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'measured_at DESC',
      );
      return rows.map(BodyMeasurementModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        BodyMeasurementModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
