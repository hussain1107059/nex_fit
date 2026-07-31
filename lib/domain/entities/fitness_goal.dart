import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// A fitness goal set by the user (or a global template when [userId] is
/// null). Templates are seeded with the database so new users can adopt one.
class FitnessGoal extends Equatable {
  const FitnessGoal({
    this.id,
    this.userId,
    required this.title,
    this.description,
    required this.goalType,
    this.targetValue,
    this.currentValue = 0,
    this.startDate,
    this.targetDate,
    this.status = GoalStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String? userId;
  final String title;
  final String? description;
  final GoalType goalType;
  final double? targetValue;
  final double currentValue;
  final DateTime? startDate;
  final DateTime? targetDate;
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isTemplate => userId == null;

  FitnessGoal copyWith({
    int? id,
    String? userId,
    String? title,
    String? description,
    GoalType? goalType,
    double? targetValue,
    double? currentValue,
    DateTime? startDate,
    DateTime? targetDate,
    GoalStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FitnessGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      goalType: goalType ?? this.goalType,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        goalType,
        targetValue,
        currentValue,
        startDate,
        targetDate,
        status,
        createdAt,
        updatedAt,
      ];
}
