import 'package:equatable/equatable.dart';

/// Global catalog of meal categories (e.g. Breakfast, Lunch, Dinner, Snacks).
class MealCategory extends Equatable {
  const MealCategory({
    this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.sortOrder = 0,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String slug;
  final String? icon;
  final int sortOrder;
  final DateTime createdAt;

  MealCategory copyWith({
    int? id,
    String? name,
    String? slug,
    String? icon,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return MealCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        icon,
        sortOrder,
        createdAt,
      ];
}
