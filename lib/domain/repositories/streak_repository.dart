import '../entities/streak.dart';

/// Contract for the user's habit streaks.
abstract interface class StreakRepository {
  Future<void> upsert(Streak streak);

  Future<Streak?> getByUserAndType(String userId, String streakType);

  Future<List<Streak>> getByUserId(String userId);

  Future<void> delete(int id);
}
