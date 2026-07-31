import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/entities/app_user.dart';

/// Maps a Firebase [fb.User] to the domain [AppUser].
class AppUserModel {
  const AppUserModel._();

  static AppUser fromFirebase(fb.User? user) {
    if (user == null) return AppUser.signedOut;

    return AppUser(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
      provider: _mapProvider(user.providerData),
      createdAt: user.metadata.creationTime,
    );
  }

  static AuthProvider _mapProvider(List<fb.UserInfo> providerData) {
    for (final fb.UserInfo info in providerData) {
      if (info.providerId == 'google.com') return AuthProvider.google;
      if (info.providerId == 'password') return AuthProvider.email;
    }
    return AuthProvider.none;
  }
}
