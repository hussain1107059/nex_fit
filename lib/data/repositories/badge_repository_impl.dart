import '../../domain/entities/badge.dart';
import '../../domain/repositories/badge_repository.dart';
import '../datasources/local/badge_local_data_source.dart';

/// SQLite backed implementation of [BadgeRepository].
class BadgeRepositoryImpl implements BadgeRepository {
  const BadgeRepositoryImpl(this._dataSource);

  final BadgeLocalDataSource _dataSource;

  @override
  Future<int> insert(Badge badge) => _dataSource.insert(badge);

  @override
  Future<void> insertAll(List<Badge> badges) => _dataSource.insertAll(badges);

  @override
  Future<void> updateAll(List<Badge> badges) => _dataSource.updateAll(badges);

  @override
  Future<void> update(Badge badge) => _dataSource.update(badge);

  @override
  Future<Badge?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<Badge>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<Badge?> getByUserAndType(String userId, String badgeType) =>
      _dataSource.getByUserAndType(userId, badgeType);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
