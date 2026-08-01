import '../entities/xp_history.dart';

abstract interface class XpHistoryRepository {
  Future<int> insert(XpHistory xpHistory);

  Future<void> update(XpHistory xpHistory);

  Future<XpHistory?> getById(int id);

  Future<List<XpHistory>> getByUserId(String userId);

  Future<XpHistory?> getByUserAndSourceAndReason(
    String userId,
    String source,
    String reason,
  );

  Future<int> totalXpForUser(String userId);

  Future<void> delete(int id);
}

typedef XPHistoryRepository = XpHistoryRepository;
