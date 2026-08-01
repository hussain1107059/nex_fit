import 'package:equatable/equatable.dart';

/// A user-specific challenge record.
class Challenge extends Equatable {
  const Challenge({
    this.id,
    required this.userId,
    required this.title,
    required this.type,
    required this.description,
    required this.difficulty,
    required this.target,
    this.progress = 0,
    this.rewardXp = 0,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final String title;
  final String type;
  final String description;
  final String difficulty;
  final int target;
  final int progress;
  final int rewardXp;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Challenge copyWith({
    int? id,
    String? userId,
    String? title,
    String? type,
    String? description,
    String? difficulty,
    int? target,
    int? progress,
    int? rewardXp,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Challenge(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      type: type ?? this.type,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      rewardXp: rewardXp ?? this.rewardXp,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    type,
    description,
    difficulty,
    target,
    progress,
    rewardXp,
    isCompleted,
    completedAt,
    createdAt,
    updatedAt,
  ];
}
