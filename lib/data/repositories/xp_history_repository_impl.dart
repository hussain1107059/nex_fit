import '../../domain/entities/xp_history.dart';
import '../../domain/repositories/xp_history_repository.dart';
import '../datasources/local/xp_history_local_data_source.dart';

class XpHistoryRepositoryImpl implements XpHistoryRepository {
  const XpHistoryRepositoryImpl(this._dataSource);

  final XpHistoryLocalDataSource _dataSource;

  @override
  Future<int> insert(XpHistory xpHistory) => _dataSource.insert(xpHistory);

  @override
  Future<void> update(XpHistory xpHistory) => _dataSource.update(xpHistory);

  @override
  Future<XpHistory?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<XpHistory>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<XpHistory?> getByUserAndSourceAndReason(
    String userId,
    String source,
    String reason,
  ) => _dataSource.getByUserAndSourceAndReason(userId, source, reason);

  @override
  Future<int> totalXpForUser(String userId) =>
      _dataSource.totalXpForUser(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
