import '../entities/milestone.dart';

abstract interface class MilestoneRepository {
  Future<int> insert(Milestone milestone);

  Future<void> update(Milestone milestone);

  Future<Milestone?> getById(int id);

  Future<List<Milestone>> getByUserId(String userId);

  Future<List<Milestone>> getByChallengeId(int challengeId);

  Future<void> delete(int id);
}
