import 'package:equatable/equatable.dart';

import 'app_user.dart';
import 'user_profile.dart';

/// Lifetime fitness statistics shown on the profile screen.
class ProfileStats extends Equatable {
  const ProfileStats({
    this.totalWorkouts = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.caloriesBurned = 0,
    this.waterIntakeMl = 0,
    this.weightLostKg,
  });

  final int totalWorkouts;
  final int currentStreak;
  final int longestStreak;
  final double caloriesBurned;
  final int waterIntakeMl;

  /// Positive when the user has lost weight since their first logged weight.
  final double? weightLostKg;

  @override
  List<Object?> get props => [
        totalWorkouts,
        currentStreak,
        longestStreak,
        caloriesBurned,
        waterIntakeMl,
        weightLostKg,
      ];
}

/// The complete aggregate backing the user profile screen.
class ProfileData extends Equatable {
  const ProfileData({
    required this.user,
    this.profile,
    this.stats = const ProfileStats(),
  });

  final AppUser user;
  final UserProfile? profile;
  final ProfileStats stats;

  @override
  List<Object?> get props => [user, profile, stats];
}
