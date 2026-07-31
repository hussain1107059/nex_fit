import 'package:equatable/equatable.dart';

/// A level-based badge with progress toward its next level.
class Badge extends Equatable {
  const Badge({
    this.id,
    required this.userId,
    required this.badgeType,
    required this.badgeName,
    this.icon,
    this.level = 1,
    this.progress = 0,
    this.target = 0,
    this.isEarned = false,
    this.earnedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final String badgeType;
  final String badgeName;
  final String? icon;
  final int level;
  final double progress;
  final double target;
  final bool isEarned;
  final DateTime? earnedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Badge copyWith({
    int? id,
    String? userId,
    String? badgeType,
    String? badgeName,
    String? icon,
    int? level,
    double? progress,
    double? target,
    bool? isEarned,
    DateTime? earnedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Badge(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      badgeType: badgeType ?? this.badgeType,
      badgeName: badgeName ?? this.badgeName,
      icon: icon ?? this.icon,
      level: level ?? this.level,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      isEarned: isEarned ?? this.isEarned,
      earnedAt: earnedAt ?? this.earnedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        badgeType,
        badgeName,
        icon,
        level,
        progress,
        target,
        isEarned,
        earnedAt,
        createdAt,
        updatedAt,
      ];
}
