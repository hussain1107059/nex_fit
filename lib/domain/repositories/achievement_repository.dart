import '../entities/achievement.dart';

/// Contract for the user's achievements.
abstract interface class AchievementRepository {
  Future<int> insert(Achievement achievement);

  /// Batches a set of new achievements in a single transaction.
  Future<void> insertAll(List<Achievement> achievements);

  Future<void> update(Achievement achievement);

  Future<Achievement?> getById(int id);

  Future<List<Achievement>> getByUserId(String userId);

  Future<void> delete(int id);
}
