import '../entities/badge.dart';

/// Contract for the user's level-based badges.
abstract interface class BadgeRepository {
  Future<int> insert(Badge badge);

  Future<void> update(Badge badge);

  Future<Badge?> getById(int id);

  Future<List<Badge>> getByUserId(String userId);

  Future<void> delete(int id);
}
