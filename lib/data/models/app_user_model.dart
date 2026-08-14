import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/app_user.dart';

/// Maps a Supabase gotrue [supabase.User] to the domain [AppUser].
class AppUserModel {
  const AppUserModel._();

  static AppUser fromSupabase(supabase.User? user) {
    if (user == null) return AppUser.signedOut;

    final Map<String, dynamic> metadata = user.userMetadata ?? const {};

    return AppUser(
      id: user.id,
      email: user.email,
      displayName: _displayName(metadata),
      photoUrl: _photoUrl(metadata),
      isEmailVerified: user.emailConfirmedAt != null,
      provider: AuthProvider.email,
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }

  static String? _displayName(Map<String, dynamic> metadata) {
    final Object? raw =
        metadata['display_name'] ?? metadata['full_name'] ?? metadata['name'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  static String? _photoUrl(Map<String, dynamic> metadata) {
    final Object? raw = metadata['avatar_url'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }
}
