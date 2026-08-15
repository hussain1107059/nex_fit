/// Estimates distance and calories for a manually logged step count.
///
/// NexFit has no pedometer integration, so a manual step entry still carries
/// sensible derived metrics for the progress reports and weekly charts.
class StepEstimator {
  const StepEstimator._();

  /// Average stride of ~0.762 m per step.
  static const double _kmPerStep = 0.000762;

  /// ~0.04 kcal per step for an average adult.
  static const double _kcalPerStep = 0.04;

  /// Distance in kilometres for [steps].
  static double distanceKm(int steps) => steps * _kmPerStep;

  /// Estimated calories burned for [steps].
  static double caloriesBurned(int steps) => steps * _kcalPerStep;
}