import '../entities/food_item.dart';
import '../entities/food_log.dart';

/// Contract for the user's food intake log.
abstract interface class FoodLogRepository {
  Future<int> insert(FoodLog log);

  Future<void> insertAll(List<FoodLog> logs);

  Future<void> update(FoodLog log);

  Future<FoodLog?> getById(int id);

  Future<List<FoodLog>> getByUserId(String userId);

  Future<List<FoodLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  /// The most recently logged foods (distinct).
  Future<List<FoodItem>> getRecentFoods(String userId, {int limit = 12});

  /// The most frequently logged foods (distinct).
  Future<List<FoodItem>> getFrequentFoods(String userId, {int limit = 12});

  Future<void> delete(int id);
}
