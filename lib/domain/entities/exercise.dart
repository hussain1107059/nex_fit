import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// A single exercise. Built-in exercises have a null [userId]; exercises the
/// user creates carry their account id.
class Exercise extends Equatable {
  const Exercise({
    this.id,
    this.userId,
    required this.name,
    this.description,
    this.instructions,
    this.bodyPart,
    this.equipment,
    this.difficulty,
    this.image,
    this.caloriesPerMinute,
    this.isCustom = false,
    required this.createdAt,
  });

  final int? id;
  final String? userId;
  final String name;
  final String? description;

  /// Step-by-step coaching text shown inside the workout player.
  final String? instructions;
  final String? bodyPart;
  final String? equipment;
  final Difficulty? difficulty;
  final String? image;
  final double? caloriesPerMinute;
  final bool isCustom;
  final DateTime createdAt;

  bool get isBuiltIn => userId == null;

  Exercise copyWith({
    int? id,
    String? userId,
    String? name,
    String? description,
    String? instructions,
    String? bodyPart,
    String? equipment,
    Difficulty? difficulty,
    String? image,
    double? caloriesPerMinute,
    bool? isCustom,
    DateTime? createdAt,
  }) {
    return Exercise(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      bodyPart: bodyPart ?? this.bodyPart,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      image: image ?? this.image,
      caloriesPerMinute: caloriesPerMinute ?? this.caloriesPerMinute,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        description,
        instructions,
        bodyPart,
        equipment,
        difficulty,
        image,
        caloriesPerMinute,
        isCustom,
        createdAt,
      ];
}
