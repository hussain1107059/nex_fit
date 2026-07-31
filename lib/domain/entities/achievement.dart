import 'package:equatable/equatable.dart';

/// An achievement unlocked by the user.
class Achievement extends Equatable {
  const Achievement({
    this.id,
    required this.userId,
    required this.name,
    this.description,
    this.achievementType,
    this.icon,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final String name;
  final String? description;
  final String? achievementType;
  final String? icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final DateTime createdAt;

  Achievement copyWith({
    int? id,
    String? userId,
    String? name,
    String? description,
    String? achievementType,
    String? icon,
    bool? isUnlocked,
    DateTime? unlockedAt,
    DateTime? createdAt,
  }) {
    return Achievement(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      achievementType: achievementType ?? this.achievementType,
      icon: icon ?? this.icon,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        description,
        achievementType,
        icon,
        isUnlocked,
        unlockedAt,
        createdAt,
      ];
}
