import 'package:equatable/equatable.dart';

/// Current XP and level standing for a user.
class LevelProgress extends Equatable {
  const LevelProgress({
    this.id,
    required this.userId,
    this.level = 1,
    this.currentXp = 0,
    this.requiredXp = 100,
    this.totalXp = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final int level;
  final int currentXp;
  final int requiredXp;
  final int totalXp;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get progressRatio => requiredXp <= 0 ? 0 : (currentXp / requiredXp).clamp(0.0, 1.0);

  LevelProgress copyWith({
    int? id,
    String? userId,
    int? level,
    int? currentXp,
    int? requiredXp,
    int? totalXp,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LevelProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
      requiredXp: requiredXp ?? this.requiredXp,
      totalXp: totalXp ?? this.totalXp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    level,
    currentXp,
    requiredXp,
    totalXp,
    createdAt,
    updatedAt,
  ];
}

typedef Level = LevelProgress;
typedef UserLevel = LevelProgress;
