import '../entities/fitness_goal.dart';

/// Contract for managing a user's fitness goals plus the global templates.
abstract interface class FitnessGoalRepository {
  Future<int> insert(FitnessGoal goal);

  Future<void> update(FitnessGoal goal);

  Future<FitnessGoal?> getById(int id);

  Future<List<FitnessGoal>> getByUserId(String userId);

  Future<List<FitnessGoal>> getTemplates();

  Future<void> delete(int id);
}
