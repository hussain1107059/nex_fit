import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// The current and best run of consecutive days for a tracked habit.
class Streak extends Equatable {
  const Streak({
    this.id,
    required this.userId,
    required this.streakType,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.bestDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final StreakType streakType;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final DateTime? bestDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Streak copyWith({
    int? id,
    String? userId,
    StreakType? streakType,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActiveDate,
    DateTime? bestDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Streak(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      streakType: streakType ?? this.streakType,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      bestDate: bestDate ?? this.bestDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        streakType,
        currentStreak,
        longestStreak,
        lastActiveDate,
        bestDate,
        createdAt,
        updatedAt,
      ];
}
