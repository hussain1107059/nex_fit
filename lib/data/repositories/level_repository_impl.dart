import '../../domain/entities/level.dart';
import '../../domain/repositories/level_repository.dart';
import '../datasources/local/level_local_data_source.dart';

class LevelRepositoryImpl implements LevelRepository {
  const LevelRepositoryImpl(this._dataSource);

  final LevelLocalDataSource _dataSource;

  @override
  Future<int> insert(LevelProgress levelProgress) =>
      _dataSource.insert(levelProgress);

  @override
  Future<void> upsert(LevelProgress levelProgress) =>
      _dataSource.upsert(levelProgress);

  @override
  Future<LevelProgress?> getById(int id) => _dataSource.getById(id);

  @override
  Future<LevelProgress?> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<LevelProgress>> getHistoryByUserId(String userId) =>
      _dataSource.getHistoryByUserId(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
