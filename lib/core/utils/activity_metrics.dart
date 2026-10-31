import 'dart:math' as math;

import '../../domain/entities/activity.dart';

/// Geometry and formatting helpers shared by the activity tracker and history.
///
/// All functions return plain Latin digits; the presentation layer converts to
/// Bangla digits when the active locale requires it.
class ActivityMetrics {
  ActivityMetrics._();

  static const double _earthRadiusMeters = 6371000;

  /// Great-circle distance in metres between two coordinates.
  static double haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final double dLat = _radians(lat2 - lat1);
    final double dLng = _radians(lng2 - lng1);
    final double a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusMeters * math.asin(math.min(1, math.sqrt(a)));
  }

  /// Total length of [route] in metres.
  static double routeDistanceMeters(List<ActivityPoint> route) {
    double total = 0;
    for (int i = 1; i < route.length; i++) {
      total += haversineMeters(
        route[i - 1].latitude,
        route[i - 1].longitude,
        route[i].latitude,
        route[i].longitude,
      );
    }
    return total;
  }

  /// Sum of positive altitude changes along [route], ignoring GPS noise below
  /// [thresholdMeters].
  static double elevationGainMeters(
    List<ActivityPoint> route, {
    double thresholdMeters = 1,
  }) {
    double gain = 0;
    double? lastAltitude;
    for (final ActivityPoint point in route) {
      final double? altitude = point.altitude;
      if (altitude == null) continue;
      if (lastAltitude != null) {
        final double delta = altitude - lastAltitude;
        if (delta >= thresholdMeters) gain += delta;
      }
      lastAltitude = altitude;
    }
    return gain;
  }

  /// Rough calorie estimate using the MET formula:
  /// `MET * 3.5 * weightKg / 200 * minutes`.
  static double estimateCalories({
    required ActivityType type,
    required int durationSeconds,
    required double weightKg,
  }) {
    final double minutes = durationSeconds / 60;
    return type.met * 3.5 * weightKg / 200 * minutes;
  }

  /// `h:mm:ss` when the hour component is non-zero, otherwise `mm:ss`.
  static String formatDuration(int seconds) {
    final int safe = math.max(0, seconds);
    final int hours = safe ~/ 3600;
    final int minutes = (safe % 3600) ~/ 60;
    final int secs = safe % 60;
    if (hours > 0) {
      return '$hours:${_two(minutes)}:${_two(secs)}';
    }
    return '${_two(minutes)}:${_two(secs)}';
  }

  /// Compact duration for cards, e.g. `1h 12m` or `18m`.
  static String formatDurationShort(int seconds) {
    final int safe = math.max(0, seconds);
    final int hours = safe ~/ 3600;
    final int minutes = (safe % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  /// `mm:ss` pace per kilometre, or `--:--` when unavailable.
  static String formatPace(double? secondsPerKm) {
    if (secondsPerKm == null || !secondsPerKm.isFinite) return '--:--';
    final int total = secondsPerKm.round();
    return '${total ~/ 60}:${_two(total % 60)}';
  }

  /// Distance in kilometres with two decimals.
  static String formatDistanceKm(double meters) {
    return (meters / 1000).toStringAsFixed(2);
  }

  /// Speed in km/h with one decimal.
  static String formatSpeedKmh(double kmh) => kmh.toStringAsFixed(1);

  static double _radians(double degrees) => degrees * math.pi / 180;

  static String _two(int value) => value.toString().padLeft(2, '0');
}
