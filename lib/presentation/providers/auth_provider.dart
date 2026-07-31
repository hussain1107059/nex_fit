import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import 'auth_controller.dart';

/// The currently signed-in user, or null / [AppUser.signedOut] otherwise.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authControllerProvider).user;
});

/// Whether a user is signed in.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final AppUser? user = ref.watch(currentUserProvider);
  return user != null && user.isSignedIn;
});

/// Whether the current user has a verified email address.
final isEmailVerifiedProvider = Provider<bool>((ref) {
  final AppUser? user = ref.watch(currentUserProvider);
  return user != null && user.isSignedIn && user.isEmailVerified;
});
