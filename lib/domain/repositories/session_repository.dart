import '../entities/app_session.dart';

/// Contract for persisting and validating secure sessions.
abstract interface class SessionRepository {
  Future<int> insert(AppSession session);

  Future<void> update(AppSession session);

  Future<AppSession?> getActiveByUserId(String userId);

  Future<List<AppSession>> getByUserId(String userId);

  Future<void> deactivateByUserId(String userId);

  Future<void> deleteInactiveOlderThan(DateTime threshold);
}
