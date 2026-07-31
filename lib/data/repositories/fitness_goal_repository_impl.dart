import '../../domain/entities/fitness_goal.dart';
import '../../domain/repositories/fitness_goal_repository.dart';
import '../datasources/local/fitness_goal_local_data_source.dart';

/// SQLite backed implementation of [FitnessGoalRepository].
class FitnessGoalRepositoryImpl implements FitnessGoalRepository {
  const FitnessGoalRepositoryImpl(this._dataSource);

  final FitnessGoalLocalDataSource _dataSource;

  @override
  Future<int> insert(FitnessGoal goal) => _dataSource.insert(goal);

  @override
  Future<void> update(FitnessGoal goal) => _dataSource.update(goal);

  @override
  Future<FitnessGoal?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<FitnessGoal>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<FitnessGoal>> getTemplates() => _dataSource.getTemplates();

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
