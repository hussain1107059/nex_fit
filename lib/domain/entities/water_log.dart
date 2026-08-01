import 'package:equatable/equatable.dart';

/// A single water intake record.
class WaterLog extends Equatable {
  const WaterLog({
    this.id,
    required this.userId,
    required this.amountMl,
    required this.loggedAt,
    required this.createdAt,
    this.note,
  });

  final int? id;
  final String userId;
  final int amountMl;
  final DateTime loggedAt;
  final DateTime createdAt;

  /// Optional free-text note attached to a custom entry.
  final String? note;

  WaterLog copyWith({
    int? id,
    String? userId,
    int? amountMl,
    DateTime? loggedAt,
    DateTime? createdAt,
    String? note,
  }) {
    return WaterLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amountMl: amountMl ?? this.amountMl,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [id, userId, amountMl, loggedAt, createdAt, note];
}
