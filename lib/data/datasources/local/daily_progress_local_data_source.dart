import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/daily_progress.dart';
import '../../models/daily_progress_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `daily_progress` table (unique per user + date).
class DailyProgressLocalDataSource extends BaseLocalDataSource {
  DailyProgressLocalDataSource({required super.database})
    : super(logName: 'DailyProgressLocalDataSource');

  Future<int> upsert(DailyProgress progress) {
    return guard('upsert', () async {
      final Database db = await dbConnection;
      return db.insert(
        DailyProgressModel.table,
        DailyProgressModel.toMap(progress),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<DailyProgress?> getByUserAndDate(
    String userId,
    DateTime progressDate,
  ) {
    return guard('get_by_user_and_date', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        DailyProgressModel.table,
        where: 'user_id = ? AND progress_date = ?',
        whereArgs: <Object?>[userId, progressDate.millisecondsSinceEpoch],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return DailyProgressModel.fromMap(rows.first);
    });
  }

  Future<List<DailyProgress>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return guard('get_by_date_range', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        DailyProgressModel.table,
        where: 'user_id = ? AND progress_date >= ? AND progress_date < ?',
        whereArgs: <Object?>[
          userId,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'progress_date ASC',
      );
      return rows.map(DailyProgressModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        DailyProgressModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
