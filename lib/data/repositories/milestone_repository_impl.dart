import '../../domain/entities/milestone.dart';
import '../../domain/repositories/milestone_repository.dart';
import '../datasources/local/milestone_local_data_source.dart';

class MilestoneRepositoryImpl implements MilestoneRepository {
  const MilestoneRepositoryImpl(this._dataSource);

  final MilestoneLocalDataSource _dataSource;

  @override
  Future<int> insert(Milestone milestone) => _dataSource.insert(milestone);

  @override
  Future<void> update(Milestone milestone) => _dataSource.update(milestone);

  @override
  Future<Milestone?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<Milestone>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<Milestone>> getByChallengeId(int challengeId) =>
      _dataSource.getByChallengeId(challengeId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
