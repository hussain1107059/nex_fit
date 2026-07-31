import 'package:equatable/equatable.dart';

/// A single water intake record.
class WaterLog extends Equatable {
  const WaterLog({
    this.id,
    required this.userId,
    required this.amountMl,
    required this.loggedAt,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final int amountMl;
  final DateTime loggedAt;
  final DateTime createdAt;

  WaterLog copyWith({
    int? id,
    String? userId,
    int? amountMl,
    DateTime? loggedAt,
    DateTime? createdAt,
  }) {
    return WaterLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amountMl: amountMl ?? this.amountMl,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, amountMl, loggedAt, createdAt];
}
