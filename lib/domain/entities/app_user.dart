import 'package:equatable/equatable.dart';

/// Authentication provider used to sign in.
enum AuthProvider { none, email, google }

/// Domain representation of the authenticated user.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
    this.provider = AuthProvider.none,
    this.createdAt,
    this.lastLogin,
  });

  /// A signed-out user. Used as the initial value of auth state streams.
  static const AppUser signedOut = AppUser(id: '');

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isEmailVerified;
  final AuthProvider provider;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  bool get isSignedIn => id.isNotEmpty;

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isEmailVerified,
    AuthProvider? provider,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        photoUrl,
        isEmailVerified,
        provider,
        createdAt,
        lastLogin,
      ];
}
