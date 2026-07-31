import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_fitness_profile_repository.dart';
import '../datasources/local/user_profile_local_data_source.dart';

/// SQLite backed implementation of [UserFitnessProfileRepository].
class UserFitnessProfileRepositoryImpl implements UserFitnessProfileRepository {
  const UserFitnessProfileRepositoryImpl(this._dataSource);

  final UserProfileLocalDataSource _dataSource;

  @override
  Future<void> upsert(UserProfile profile) async {
    await _dataSource.upsert(profile);
  }

  @override
  Future<UserProfile?> getById(String userId) => _dataSource.getById(userId);

  @override
  Future<void> delete(String userId) => _dataSource.delete(userId);
}
