import '../../domain/entities/achievement.dart';
import '../../domain/repositories/achievement_repository.dart';
import '../datasources/local/achievement_local_data_source.dart';

/// SQLite backed implementation of [AchievementRepository].
class AchievementRepositoryImpl implements AchievementRepository {
  const AchievementRepositoryImpl(this._dataSource);

  final AchievementLocalDataSource _dataSource;

  @override
  Future<int> insert(Achievement achievement) =>
      _dataSource.insert(achievement);

  @override
  Future<void> insertAll(List<Achievement> achievements) =>
      _dataSource.insertAll(achievements);

  @override
  Future<void> update(Achievement achievement) => _dataSource.update(achievement);

  @override
  Future<Achievement?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<Achievement>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
