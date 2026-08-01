import 'package:equatable/equatable.dart';

/// A reward claim for the user such as coins, badges, or XP.
class Reward extends Equatable {
  const Reward({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.amount,
    this.icon,
    this.isClaimed = false,
    this.claimedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final String type;
  final String title;
  final int amount;
  final String? icon;
  final bool isClaimed;
  final DateTime? claimedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reward copyWith({
    int? id,
    String? userId,
    String? type,
    String? title,
    int? amount,
    String? icon,
    bool? isClaimed,
    DateTime? claimedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reward(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      icon: icon ?? this.icon,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedAt: claimedAt ?? this.claimedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    title,
    amount,
    icon,
    isClaimed,
    claimedAt,
    createdAt,
    updatedAt,
  ];
}
