import '../entities/activity.dart';

/// Contract for persisted GPS activity sessions.
abstract interface class ActivityRepository {
  Future<int> insert(ActivitySession session);

  Future<void> update(ActivitySession session);

  Future<ActivitySession?> getById(int id);

  Future<List<ActivitySession>> getByUserId(String userId, {int limit = 50});

  Future<ActivityStats> getStats(String userId);

  Future<void> delete(int id);
}
