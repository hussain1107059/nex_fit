import '../entities/user_profile.dart';

/// Contract for persisting and reading the user's extended fitness profile
/// (physical stats and daily targets) stored in the `user_profile` table.
abstract interface class UserFitnessProfileRepository {
  Future<void> upsert(UserProfile profile);

  Future<UserProfile?> getById(String userId);

  Future<void> delete(String userId);
}
