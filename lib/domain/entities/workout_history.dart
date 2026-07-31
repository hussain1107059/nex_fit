import 'package:equatable/equatable.dart';

/// A completed (or in-progress) workout session recorded in history.
class WorkoutHistory extends Equatable {
  const WorkoutHistory({
    this.id,
    required this.userId,
    this.workoutId,
    required this.startedAt,
    this.endedAt,
    this.durationMinutes,
    this.caloriesBurn,
    this.notes,
    this.isCompleted = false,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final int? workoutId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final double? caloriesBurn;
  final String? notes;
  final bool isCompleted;
  final DateTime createdAt;

  WorkoutHistory copyWith({
    int? id,
    String? userId,
    int? workoutId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationMinutes,
    double? caloriesBurn,
    String? notes,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return WorkoutHistory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workoutId: workoutId ?? this.workoutId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      caloriesBurn: caloriesBurn ?? this.caloriesBurn,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        workoutId,
        startedAt,
        endedAt,
        durationMinutes,
        caloriesBurn,
        notes,
        isCompleted,
        createdAt,
      ];
}
