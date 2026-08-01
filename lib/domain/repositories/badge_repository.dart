import '../entities/badge.dart';

/// Contract for the user's level-based badges.
abstract interface class BadgeRepository {
  Future<int> insert(Badge badge);

  /// Batches a set of new badges in a single transaction.
  Future<void> insertAll(List<Badge> badges);

  Future<void> update(Badge badge);

  /// Batches a set of existing badges in a single transaction.
  Future<void> updateAll(List<Badge> badges);

  Future<Badge?> getById(int id);

  Future<List<Badge>> getByUserId(String userId);

  Future<Badge?> getByUserAndType(String userId, String badgeType);

  Future<void> delete(int id);
}
