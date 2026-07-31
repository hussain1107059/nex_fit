import '../../domain/entities/common_enums.dart';
import '../../domain/entities/fitness_goal.dart';
import 'model_codec.dart';

/// Maps [FitnessGoal] to and from rows in the `fitness_goal` table.
class FitnessGoalModel {
  FitnessGoalModel._();

  static const String table = 'fitness_goal';

  static Map<String, Object?> toMap(FitnessGoal goal) {
    return <String, Object?>{
      'id': goal.id,
      'user_id': goal.userId,
      'title': goal.title,
      'description': goal.description,
      'goal_type': goal.goalType.name,
      'target_value': goal.targetValue,
      'current_value': goal.currentValue,
      'start_date': ModelCodec.epochMs(goal.startDate),
      'target_date': ModelCodec.epochMs(goal.targetDate),
      'status': goal.status.name,
      'created_at': ModelCodec.epochMs(goal.createdAt),
      'updated_at': ModelCodec.epochMs(goal.updatedAt),
    };
  }

  static FitnessGoal fromMap(Map<String, Object?> row) {
    return FitnessGoal(
      id: row['id'] as int?,
      userId: row['user_id'] as String?,
      title: row['title'] as String,
      description: row['description'] as String?,
      goalType: GoalType.fromName(row['goal_type'] as String?),
      targetValue: ModelCodec.toDouble(row['target_value']),
      currentValue: ModelCodec.toDouble(row['current_value']) ?? 0,
      startDate: ModelCodec.fromEpochMs(row['start_date'] as int?),
      targetDate: ModelCodec.fromEpochMs(row['target_date'] as int?),
      status: GoalStatus.fromName(row['status'] as String?),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
