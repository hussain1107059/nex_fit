import 'package:geolocator/geolocator.dart';

import '../../../domain/entities/activity.dart';

/// Why GPS tracking cannot start.
enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
}

/// Thrown when location access or a GPS fix is not available.
class LocationException implements Exception {
  const LocationException(this.failure);

  final LocationFailure failure;

  @override
  String toString() => 'LocationException($failure)';
}

/// Thin wrapper around [Geolocator] so the tracking controller and widgets do
/// not depend on the plugin directly.
class LocationService {
  const LocationService();

  /// Ensures location services are on and permission is granted.
  ///
  /// Requests permission when it has not been decided yet. Throws a
  /// [LocationException] describing the blocker otherwise.
  Future<void> ensureReady() async {
    final bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        LocationFailure.permissionPermanentlyDenied,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationFailure.permissionDenied);
    }
  }

  /// A single fix used to centre the map before tracking starts.
  Future<ActivityPoint?> currentPoint() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return _toPoint(position);
    } on Exception {
      return null;
    }
  }

  /// Continuous fixes. Errors are swallowed by the caller with
  /// [Stream.handleError] so a transient GPS dropout does not end the session.
  Stream<ActivityPoint> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        timeLimit: Duration(seconds: 20),
      ),
    ).map(_toPoint);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static ActivityPoint _toPoint(Position position) {
    return ActivityPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: position.timestamp,
      altitude: position.hasAltitude ? position.altitude : null,
      speed: position.hasSpeed ? position.speed : null,
      accuracy: position.hasAccuracy ? position.accuracy : null,
    );
  }
}
