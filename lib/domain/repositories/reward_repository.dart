import '../entities/reward.dart';

abstract interface class RewardRepository {
  Future<int> insert(Reward reward);

  Future<void> update(Reward reward);

  Future<Reward?> getById(int id);

  Future<List<Reward>> getByUserId(String userId);

  Future<Reward?> getByUserAndType(String userId, String type, String title);

  Future<void> delete(int id);
}
