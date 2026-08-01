import 'package:equatable/equatable.dart';

/// A secure session record for a signed-in user.
///
/// Persisted inside the local `sessions` table. The token is randomly
/// generated and never exposed to the UI; validation relies on the token,
/// the stable device id and the expiry timestamps.
class AppSession extends Equatable {
  const AppSession({
    this.id,
    required this.userId,
    required this.token,
    required this.deviceId,
    required this.createdAt,
    required this.expiresAt,
    required this.lastActivityAt,
    this.isActive = true,
  });

  final int? id;
  final String userId;
  final String token;
  final String deviceId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime lastActivityAt;
  final bool isActive;

  AppSession copyWith({
    int? id,
    String? userId,
    String? token,
    String? deviceId,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? lastActivityAt,
    bool? isActive,
  }) {
    return AppSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, token, deviceId, createdAt, expiresAt, lastActivityAt, isActive];
}
