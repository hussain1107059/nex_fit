import '../entities/achievement.dart';

/// Contract for the user's achievements.
abstract interface class AchievementRepository {
  Future<int> insert(Achievement achievement);

  Future<void> update(Achievement achievement);

  Future<Achievement?> getById(int id);

  Future<List<Achievement>> getByUserId(String userId);

  Future<void> delete(int id);
}
