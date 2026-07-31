import '../../domain/entities/daily_progress.dart';
import '../../domain/repositories/daily_progress_repository.dart';
import '../datasources/local/daily_progress_local_data_source.dart';

/// SQLite backed implementation of [DailyProgressRepository].
class DailyProgressRepositoryImpl implements DailyProgressRepository {
  const DailyProgressRepositoryImpl(this._dataSource);

  final DailyProgressLocalDataSource _dataSource;

  @override
  Future<void> upsert(DailyProgress progress) async {
    await _dataSource.upsert(progress);
  }

  @override
  Future<DailyProgress?> getByUserAndDate(
    String userId,
    DateTime progressDate,
  ) => _dataSource.getByUserAndDate(userId, progressDate);

  @override
  Future<List<DailyProgress>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) => _dataSource.getByDateRange(userId, start, end);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
