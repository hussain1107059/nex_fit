import '../entities/challenge.dart';

abstract interface class ChallengeRepository {
  Future<int> insert(Challenge challenge);

  Future<void> update(Challenge challenge);

  Future<Challenge?> getById(int id);

  Future<List<Challenge>> getByUserId(String userId);

  Future<Challenge?> getByUserAndType(String userId, String type);

  Future<void> delete(int id);
}
