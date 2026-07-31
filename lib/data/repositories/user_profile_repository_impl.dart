import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/local/user_local_data_source.dart';

/// SQLite backed implementation of [UserProfileRepository].
/// Exceptions raised by the data source (e.g. [DatabaseException]) are
/// allowed to propagate and are mapped to failures by the use case layer.
class UserProfileRepositoryImpl implements UserProfileRepository {
  const UserProfileRepositoryImpl(this._dataSource);

  final UserLocalDataSource _dataSource;

  @override
  Future<void> saveProfile(AppUser user) => _dataSource.saveProfile(user);

  @override
  Future<AppUser?> getProfile(String uid) => _dataSource.getProfile(uid);

  @override
  Future<void> updateLastLogin(String uid) => _dataSource.updateLastLogin(uid);

  @override
  Future<void> deleteProfile(String uid) => _dataSource.deleteProfile(uid);
}
