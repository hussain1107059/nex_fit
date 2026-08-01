import '../../domain/entities/challenge.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../datasources/local/challenge_local_data_source.dart';

class ChallengeRepositoryImpl implements ChallengeRepository {
  const ChallengeRepositoryImpl(this._dataSource);

  final ChallengeLocalDataSource _dataSource;

  @override
  Future<int> insert(Challenge challenge) => _dataSource.insert(challenge);

  @override
  Future<void> update(Challenge challenge) => _dataSource.update(challenge);

  @override
  Future<Challenge?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<Challenge>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<Challenge?> getByUserAndType(String userId, String type) =>
      _dataSource.getByUserAndType(userId, type);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
