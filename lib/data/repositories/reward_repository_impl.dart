import '../../domain/entities/reward.dart';
import '../../domain/repositories/reward_repository.dart';
import '../datasources/local/reward_local_data_source.dart';

class RewardRepositoryImpl implements RewardRepository {
  const RewardRepositoryImpl(this._dataSource);

  final RewardLocalDataSource _dataSource;

  @override
  Future<int> insert(Reward reward) => _dataSource.insert(reward);

  @override
  Future<void> update(Reward reward) => _dataSource.update(reward);

  @override
  Future<Reward?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<Reward>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<Reward?> getByUserAndType(String userId, String type, String title) =>
      _dataSource.getByUserAndType(userId, type, title);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
