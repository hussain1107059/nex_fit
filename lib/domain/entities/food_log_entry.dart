import 'package:equatable/equatable.dart';

import 'food_item.dart';
import 'food_log.dart';

/// A single consumed food: the log snapshot plus the live food reference.
class FoodLogEntry extends Equatable {
  const FoodLogEntry({required this.log, this.food});

  final FoodLog log;
  final FoodItem? food;

  double get calories => log.calories;
  double get protein => log.protein;
  double get carbs => log.carbs;
  double get fat => log.fat;
  double get fiber => log.fiber;
  double get sugar => log.sugar;

  @override
  List<Object?> get props => [log, food];
}
