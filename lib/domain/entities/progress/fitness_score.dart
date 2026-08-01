import 'package:equatable/equatable.dart';

/// One component of the composite fitness score (0..100).
class FitnessScoreMetric extends Equatable {
  const FitnessScoreMetric({
    required this.key,
    required this.label,
    required this.score,
  });

  final String key;
  final String label;
  final int score;

  @override
  List<Object?> get props => [key, label, score];
}

/// A composite 0..100 score summarising the user's overall fitness habits.
class FitnessScore extends Equatable {
  const FitnessScore({
    required this.score,
    required this.label,
    required this.metrics,
  });

  /// Weighted composite score from 0 to 100.
  final int score;

  /// Short grade such as "Excellent" or "Good".
  final String label;

  /// Individual component scores used to explain the total.
  final List<FitnessScoreMetric> metrics;

  @override
  List<Object?> get props => [score, label, metrics];
}
