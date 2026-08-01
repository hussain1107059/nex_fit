import '../entities/level.dart';

abstract interface class LevelRepository {
  Future<int> insert(LevelProgress levelProgress);

  Future<void> upsert(LevelProgress levelProgress);

  Future<LevelProgress?> getById(int id);

  Future<LevelProgress?> getByUserId(String userId);

  Future<List<LevelProgress>> getHistoryByUserId(String userId);

  Future<void> delete(int id);
}

typedef UserLevelRepository = LevelRepository;
