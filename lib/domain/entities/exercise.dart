import 'package:equatable/equatable.dart';

import 'common_enums.dart';
import 'exercise_category.dart';

/// A single exercise. Built-in exercises have a null [userId]; exercises the
/// user creates carry their account id.
class Exercise extends Equatable {
  const Exercise({
    this.id,
    this.userId,
    required this.name,
    this.scientificName,
    this.description,
    this.instructions,
    this.bodyPart,
    this.secondaryMuscle,
    this.equipment,
    this.difficulty,
    this.category,
    this.image,
    this.gifPath,
    this.caloriesPerMinute,
    this.estimatedCalories,
    this.durationSeconds = 30,
    this.sets = 3,
    this.reps = 12,
    this.restSeconds = 30,
    this.tips = const <String>[],
    this.commonMistakes = const <String>[],
    this.safetyInstructions = const <String>[],
    this.isFavorite = false,
    this.isCustom = false,
    required this.createdAt,
  });

  final int? id;
  final String? userId;
  final String name;

  /// Formal or scientific name (e.g. "Pectoralis Major"), optional.
  final String? scientificName;

  final String? description;

  /// Step-by-step coaching text shown inside the workout player.
  final String? instructions;

  /// Primary target muscle group, e.g. "Chest".
  final String? bodyPart;

  /// Secondary muscle groups, e.g. "Triceps, Anterior Deltoids".
  final String? secondaryMuscle;

  final String? equipment;
  final Difficulty? difficulty;

  /// Library category the exercise belongs to.
  final ExerciseCategory? category;

  /// Optional cover image path. When null the UI renders a generated cover.
  final String? image;

  /// Optional animation (GIF) path shown inside the player.
  final String? gifPath;

  final double? caloriesPerMinute;

  /// Estimated calories burned for the suggested program, in kcal.
  final double? estimatedCalories;

  /// Suggested program defaults used by the library and the player.
  final int durationSeconds;
  final int sets;
  final int reps;
  final int restSeconds;

  /// Coaching notes split per category.
  final List<String> tips;
  final List<String> commonMistakes;
  final List<String> safetyInstructions;

  final bool isFavorite;
  final bool isCustom;
  final DateTime createdAt;

  bool get isBuiltIn => userId == null;

  /// Total active seconds for one pass of the suggested program.
  int get totalDurationSeconds => sets > 0 ? sets * durationSeconds : durationSeconds;

  /// Estimated calories for one full pass of the suggested program.
  double get totalEstimatedCalories {
    if (estimatedCalories != null && estimatedCalories! > 0) {
      return estimatedCalories!;
    }
    final double? perMinute = caloriesPerMinute;
    if (perMinute == null || perMinute <= 0) return 0;
    return perMinute * totalDurationSeconds / 60;
  }

  Exercise copyWith({
    int? id,
    String? userId,
    String? name,
    String? scientificName,
    String? description,
    String? instructions,
    String? bodyPart,
    String? secondaryMuscle,
    String? equipment,
    Difficulty? difficulty,
    ExerciseCategory? category,
    String? image,
    String? gifPath,
    double? caloriesPerMinute,
    double? estimatedCalories,
    int? durationSeconds,
    int? sets,
    int? reps,
    int? restSeconds,
    List<String>? tips,
    List<String>? commonMistakes,
    List<String>? safetyInstructions,
    bool? isFavorite,
    bool? isCustom,
    DateTime? createdAt,
  }) {
    return Exercise(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      scientificName: scientificName ?? this.scientificName,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      bodyPart: bodyPart ?? this.bodyPart,
      secondaryMuscle: secondaryMuscle ?? this.secondaryMuscle,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
      image: image ?? this.image,
      gifPath: gifPath ?? this.gifPath,
      caloriesPerMinute: caloriesPerMinute ?? this.caloriesPerMinute,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      restSeconds: restSeconds ?? this.restSeconds,
      tips: tips ?? this.tips,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      safetyInstructions: safetyInstructions ?? this.safetyInstructions,
      isFavorite: isFavorite ?? this.isFavorite,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        scientificName,
        description,
        instructions,
        bodyPart,
        secondaryMuscle,
        equipment,
        difficulty,
        category,
        image,
        gifPath,
        caloriesPerMinute,
        estimatedCalories,
        durationSeconds,
        sets,
        reps,
        restSeconds,
        tips,
        commonMistakes,
        safetyInstructions,
        isFavorite,
        isCustom,
        createdAt,
      ];
}
