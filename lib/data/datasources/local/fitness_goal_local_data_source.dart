import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/fitness_goal.dart';
import '../../models/fitness_goal_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `fitness_goal` table.
class FitnessGoalLocalDataSource extends BaseLocalDataSource {
  FitnessGoalLocalDataSource({required super.database})
    : super(logName: 'FitnessGoalLocalDataSource');

  Future<int> insert(FitnessGoal goal) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        FitnessGoalModel.table,
        FitnessGoalModel.toMap(goal),
      );
    });
  }

  Future<void> update(FitnessGoal goal) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        FitnessGoalModel.table,
        FitnessGoalModel.toMap(goal),
        where: 'id = ?',
        whereArgs: <Object?>[goal.id],
      );
    });
  }

  Future<FitnessGoal?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FitnessGoalModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return FitnessGoalModel.fromMap(rows.first);
    });
  }

  Future<List<FitnessGoal>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FitnessGoalModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(FitnessGoalModel.fromMap).toList();
    });
  }

  Future<List<FitnessGoal>> getTemplates() {
    return guard('get_templates', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FitnessGoalModel.table,
        where: 'user_id IS NULL',
        orderBy: 'id ASC',
      );
      return rows.map(FitnessGoalModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        FitnessGoalModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
