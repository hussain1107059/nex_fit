import '../entities/app_user.dart';

/// Contract for persisting and reading the user's local profile
/// stored inside the app's SQLite database.
abstract interface class UserProfileRepository {
  Future<void> saveProfile(AppUser user);

  Future<AppUser?> getProfile(String uid);

  Future<void> updateLastLogin(String uid);

  Future<void> deleteProfile(String uid);
}
