import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// A workout routine the user owns, optionally grouped into a category.
class Workout extends Equatable {
  const Workout({
    this.id,
    required this.userId,
    this.categoryId,
    required this.name,
    this.description,
    this.difficulty,
    this.durationMinutes,
    this.caloriesBurn,
    this.image,
    this.isFavorite = false,
    this.isCustom = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final int? categoryId;
  final String name;
  final String? description;
  final Difficulty? difficulty;
  final int? durationMinutes;
  final double? caloriesBurn;

  /// Optional cover image. When null the UI renders a generated cover.
  final String? image;
  final bool isFavorite;
  final bool isCustom;
  final DateTime createdAt;
  final DateTime updatedAt;

  Workout copyWith({
    int? id,
    String? userId,
    int? categoryId,
    String? name,
    String? description,
    Difficulty? difficulty,
    int? durationMinutes,
    double? caloriesBurn,
    String? image,
    bool? isFavorite,
    bool? isCustom,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workout(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      caloriesBurn: caloriesBurn ?? this.caloriesBurn,
      image: image ?? this.image,
      isFavorite: isFavorite ?? this.isFavorite,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        categoryId,
        name,
        description,
        difficulty,
        durationMinutes,
        caloriesBurn,
        image,
        isFavorite,
        isCustom,
        createdAt,
        updatedAt,
      ];
}
