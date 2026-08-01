import 'package:equatable/equatable.dart';

/// A nested checkpoint inside a larger challenge.
class Milestone extends Equatable {
  const Milestone({
    this.id,
    required this.userId,
    this.challengeId,
    required this.title,
    required this.targetValue,
    this.currentValue = 0,
    this.isReached = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final int? challengeId;
  final String title;
  final int targetValue;
  final int currentValue;
  final bool isReached;
  final DateTime createdAt;
  final DateTime updatedAt;

  Milestone copyWith({
    int? id,
    String? userId,
    int? challengeId,
    String? title,
    int? targetValue,
    int? currentValue,
    bool? isReached,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Milestone(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      challengeId: challengeId ?? this.challengeId,
      title: title ?? this.title,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      isReached: isReached ?? this.isReached,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    challengeId,
    title,
    targetValue,
    currentValue,
    isReached,
    createdAt,
    updatedAt,
  ];
}
