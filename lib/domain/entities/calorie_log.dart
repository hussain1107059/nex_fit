import 'package:equatable/equatable.dart';

/// A daily calorie summary for the user.
class CalorieLog extends Equatable {
  const CalorieLog({
    this.id,
    required this.userId,
    this.caloriesConsumed = 0,
    this.caloriesBurned = 0,
    this.netCalories = 0,
    required this.loggedAt,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final double caloriesConsumed;
  final double caloriesBurned;
  final double netCalories;
  final DateTime loggedAt;
  final DateTime createdAt;

  CalorieLog copyWith({
    int? id,
    String? userId,
    double? caloriesConsumed,
    double? caloriesBurned,
    double? netCalories,
    DateTime? loggedAt,
    DateTime? createdAt,
  }) {
    return CalorieLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      caloriesConsumed: caloriesConsumed ?? this.caloriesConsumed,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      netCalories: netCalories ?? this.netCalories,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        caloriesConsumed,
        caloriesBurned,
        netCalories,
        loggedAt,
        createdAt,
      ];
}
