import 'package:equatable/equatable.dart';

/// Global catalog of workout categories (e.g. Home Workout, Cardio, Yoga).
class WorkoutCategory extends Equatable {
  const WorkoutCategory({
    this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.color,
    this.sortOrder = 0,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final int? color;
  final int sortOrder;
  final DateTime createdAt;

  WorkoutCategory copyWith({
    int? id,
    String? name,
    String? slug,
    String? description,
    String? icon,
    int? color,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return WorkoutCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        description,
        icon,
        color,
        sortOrder,
        createdAt,
      ];
}
