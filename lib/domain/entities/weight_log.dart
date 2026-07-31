import 'package:equatable/equatable.dart';

/// A body weight measurement record.
class WeightLog extends Equatable {
  const WeightLog({
    this.id,
    required this.userId,
    required this.weightKg,
    this.note,
    required this.loggedAt,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final double weightKg;
  final String? note;
  final DateTime loggedAt;
  final DateTime createdAt;

  WeightLog copyWith({
    int? id,
    String? userId,
    double? weightKg,
    String? note,
    DateTime? loggedAt,
    DateTime? createdAt,
  }) {
    return WeightLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      weightKg: weightKg ?? this.weightKg,
      note: note ?? this.note,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, weightKg, note, loggedAt, createdAt];
}
