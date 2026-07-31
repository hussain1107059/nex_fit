import '../entities/daily_progress.dart';

/// Contract for the user's per-day aggregated progress.
abstract interface class DailyProgressRepository {
  Future<void> upsert(DailyProgress progress);

  Future<DailyProgress?> getByUserAndDate(
    String userId,
    DateTime progressDate,
  );

  Future<List<DailyProgress>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  Future<void> delete(int id);
}
