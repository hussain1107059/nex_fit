import '../../domain/entities/app_user.dart';

/// Maps [AppUser] to and from rows in the local `users` table.
class LocalUserModel {
  LocalUserModel._();

  static const String table = 'users';

  static Map<String, Object?> toMap(AppUser user) {
    return <String, Object?>{
      'id': user.id,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'photo': user.photoUrl,
      'provider': user.provider.name,
      'created_at': user.createdAt?.millisecondsSinceEpoch,
      'last_login': user.lastLogin?.millisecondsSinceEpoch,
    };
  }

  static AppUser fromMap(Map<String, Object?> row) {
    final int? createdAt = row['created_at'] as int?;
    final int? lastLogin = row['last_login'] as int?;

    return AppUser(
      id: row['id'] as String,
      email: row['email'] as String?,
      displayName: row['name'] as String?,
      photoUrl: row['photo'] as String?,
      provider: _mapProvider(row['provider'] as String?),
      createdAt: createdAt != null
          ? DateTime.fromMillisecondsSinceEpoch(createdAt)
          : null,
      lastLogin: lastLogin != null
          ? DateTime.fromMillisecondsSinceEpoch(lastLogin)
          : null,
    );
  }

  static AuthProvider _mapProvider(String? value) {
    return AuthProvider.values.firstWhere(
      (provider) => provider.name == value,
      orElse: () => AuthProvider.none,
    );
  }
}
