import 'package:equatable/equatable.dart';

/// A GPS-tracked outdoor activity supported by the tracker.
enum ActivityType {
  walking('walking'),
  running('running'),
  cycling('cycling'),
  swimming('swimming');

  const ActivityType(this.value);

  /// Stable value persisted in the `activity_session.activity_type` column.
  final String value;

  /// MET (metabolic equivalent) used to estimate calories burned.
  double get met => switch (this) {
    ActivityType.walking => 3.5,
    ActivityType.running => 8.3,
    ActivityType.cycling => 6.8,
    ActivityType.swimming => 6.0,
  };

  /// Whether pace (min/km) is a meaningful metric for this activity.
  bool get usesPace =>
      this == ActivityType.walking || this == ActivityType.running;

  /// Whether a step-count target can be used for this activity.
  ///
  /// Swimming only supports distance targets because the phone is not carried
  /// on the body during a swim.
  bool get supportsStepTarget => this != ActivityType.swimming;

  static ActivityType fromValue(String value) => ActivityType.values.firstWhere(
    (ActivityType type) => type.value == value,
    orElse: () => ActivityType.walking,
  );
}

/// Unit used by an activity target.
enum ActivityGoalType {
  distance('distance'),
  steps('steps');

  const ActivityGoalType(this.value);

  /// Stable value persisted in the `activity_session.goal_type` column.
  final String value;

  static ActivityGoalType? fromValue(String? value) {
    if (value == null) return null;
    for (final ActivityGoalType type in ActivityGoalType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// A target to reach while tracking: either a distance in metres or a step
/// count.
class ActivityGoal extends Equatable {
  const ActivityGoal({required this.type, required this.value});

  const ActivityGoal.distance(this.value) : type = ActivityGoalType.distance;

  const ActivityGoal.steps(this.value) : type = ActivityGoalType.steps;

  final ActivityGoalType type;

  /// Distance in metres for [ActivityGoalType.distance], step count for
  /// [ActivityGoalType.steps].
  final double value;

  bool get isDistance => type == ActivityGoalType.distance;

  bool get isSteps => type == ActivityGoalType.steps;

  int get targetSteps => value.round();

  bool isReached({required double distanceMeters, required int steps}) =>
      switch (type) {
        ActivityGoalType.distance => distanceMeters >= value,
        ActivityGoalType.steps => steps >= targetSteps,
      };

  @override
  List<Object?> get props => <Object?>[type, value];
}

/// One recorded GPS sample along an activity route.
class ActivityPoint extends Equatable {
  const ActivityPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.altitude,
    this.speed,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? altitude;
  final double? speed;
  final double? accuracy;

  /// Compact storage form:
  /// `[lat, lng, epochMs, altitude, speed, accuracy]`.
  List<Object?> toStorage() => <Object?>[
    latitude,
    longitude,
    recordedAt.millisecondsSinceEpoch,
    altitude,
    speed,
    accuracy,
  ];

  static ActivityPoint fromStorage(Object? raw) {
    if (raw is! List || raw.length < 3) {
      throw const FormatException('Invalid activity point');
    }
    return ActivityPoint(
      latitude: (raw[0] as num).toDouble(),
      longitude: (raw[1] as num).toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch((raw[2] as num).toInt()),
      altitude: raw.length > 3 ? (raw[3] as num?)?.toDouble() : null,
      speed: raw.length > 4 ? (raw[4] as num?)?.toDouble() : null,
      accuracy: raw.length > 5 ? (raw[5] as num?)?.toDouble() : null,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    latitude,
    longitude,
    recordedAt,
    altitude,
    speed,
    accuracy,
  ];
}

/// A completed activity session with its aggregated metrics and route.
class ActivitySession extends Equatable {
  const ActivitySession({
    this.id,
    required this.userId,
    required this.type,
    required this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    this.caloriesBurned = 0,
    this.elevationGainMeters = 0,
    this.avgSpeedMps = 0,
    this.maxSpeedMps = 0,
    this.steps = 0,
    this.goalType,
    this.goalValue,
    this.goalReached = false,
    this.route = const <ActivityPoint>[],
    this.note,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final ActivityType type;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double caloriesBurned;
  final double elevationGainMeters;
  final double avgSpeedMps;
  final double maxSpeedMps;
  final int steps;
  final ActivityGoalType? goalType;
  final double? goalValue;
  final bool goalReached;
  final List<ActivityPoint> route;
  final String? note;
  final DateTime createdAt;

  double get distanceKm => distanceMeters / 1000;

  /// The saved target, or null when the session had no target.
  ActivityGoal? get goal {
    final ActivityGoalType? type = goalType;
    final double? value = goalValue;
    if (type == null || value == null || value <= 0) return null;
    return ActivityGoal(type: type, value: value);
  }

  double get durationHours => durationSeconds / 3600;

  /// Average speed in km/h, derived from distance and duration when the
  /// recorded value is missing (for example, sessions stored before v21).
  double get averageSpeedKmh =>
      avgSpeedMps > 0 ? avgSpeedMps * 3.6 : speedKmhFromDistance;

  double get speedKmhFromDistance =>
      durationSeconds > 0 ? distanceMeters / durationSeconds * 3.6 : 0;

  /// Seconds per kilometre, or null when the distance is too small.
  double? get paceSecondsPerKm =>
      distanceMeters > 5 ? durationSeconds / distanceKm : null;

  ActivitySession copyWith({
    int? id,
    String? userId,
    ActivityType? type,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    double? distanceMeters,
    double? caloriesBurned,
    double? elevationGainMeters,
    double? avgSpeedMps,
    double? maxSpeedMps,
    int? steps,
    ActivityGoalType? goalType,
    double? goalValue,
    bool? goalReached,
    List<ActivityPoint>? route,
    String? note,
    DateTime? createdAt,
  }) {
    return ActivitySession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      avgSpeedMps: avgSpeedMps ?? this.avgSpeedMps,
      maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
      steps: steps ?? this.steps,
      goalType: goalType ?? this.goalType,
      goalValue: goalValue ?? this.goalValue,
      goalReached: goalReached ?? this.goalReached,
      route: route ?? this.route,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    userId,
    type,
    startedAt,
    endedAt,
    durationSeconds,
    distanceMeters,
    caloriesBurned,
    elevationGainMeters,
    avgSpeedMps,
    maxSpeedMps,
    steps,
    goalType,
    goalValue,
    goalReached,
    route,
    note,
    createdAt,
  ];
}

/// Lifetime aggregate shown on the activity home screen.
class ActivityStats extends Equatable {
  const ActivityStats({
    this.totalSessions = 0,
    this.totalDistanceMeters = 0,
    this.totalDurationSeconds = 0,
    this.totalCalories = 0,
  });

  final int totalSessions;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final double totalCalories;

  double get totalDistanceKm => totalDistanceMeters / 1000;

  @override
  List<Object?> get props => <Object?>[
    totalSessions,
    totalDistanceMeters,
    totalDurationSeconds,
    totalCalories,
  ];
}
