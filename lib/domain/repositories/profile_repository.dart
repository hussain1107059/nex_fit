import '../entities/profile_data.dart';
import '../entities/user_profile.dart';

/// Contract for reading and writing the complete user profile aggregate.
/// Implemented by [ProfileRepositoryImpl] in the data layer.
abstract interface class ProfileRepository {
  /// Loads the signed-in user, their extended profile and lifetime stats.
  Future<ProfileData> load(String userId);

  /// Upserts the extended fitness profile row.
  Future<void> saveProfile(UserProfile profile);

  /// Reads the extended fitness profile row.
  Future<UserProfile?> getProfile(String userId);

  /// Updates the display name stored on the local `users` row.
  Future<void> updateName(String userId, String name);
}
