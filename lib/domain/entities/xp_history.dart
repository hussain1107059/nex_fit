import 'package:equatable/equatable.dart';

/// A single XP award event for a user.
class XpHistory extends Equatable {
  const XpHistory({
    this.id,
    required this.userId,
    required this.source,
    required this.reason,
    required this.xp,
    this.totalXp = 0,
    this.metadata,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final String source;
  final String reason;
  final int xp;
  final int totalXp;
  final String? metadata;
  final DateTime createdAt;

  XpHistory copyWith({
    int? id,
    String? userId,
    String? source,
    String? reason,
    int? xp,
    int? totalXp,
    String? metadata,
    DateTime? createdAt,
  }) {
    return XpHistory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      source: source ?? this.source,
      reason: reason ?? this.reason,
      xp: xp ?? this.xp,
      totalXp: totalXp ?? this.totalXp,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    source,
    reason,
    xp,
    totalXp,
    metadata,
    createdAt,
  ];
}

typedef XPHistory = XpHistory;
