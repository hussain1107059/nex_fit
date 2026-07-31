import '../../domain/entities/streak.dart';
import '../../domain/repositories/streak_repository.dart';
import '../datasources/local/streak_local_data_source.dart';

/// SQLite backed implementation of [StreakRepository].
class StreakRepositoryImpl implements StreakRepository {
  const StreakRepositoryImpl(this._dataSource);

  final StreakLocalDataSource _dataSource;

  @override
  Future<void> upsert(Streak streak) async {
    await _dataSource.upsert(streak);
  }

  @override
  Future<Streak?> getByUserAndType(String userId, String streakType) =>
      _dataSource.getByUserAndType(userId, streakType);

  @override
  Future<List<Streak>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
