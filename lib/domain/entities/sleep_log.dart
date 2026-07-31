import 'package:equatable/equatable.dart';

/// Sleep recorded for a given date (in [sleepDate]).
class SleepLog extends Equatable {
  const SleepLog({
    this.id,
    required this.userId,
    required this.sleepDate,
    required this.durationMinutes,
    this.bedtime,
    this.wakeTime,
    this.quality = 0,
    this.note,
    required this.createdAt,
  });

  final int? id;
  final String userId;

  /// The day this sleep belongs to (date only, epoch milliseconds).
  final DateTime sleepDate;
  final int durationMinutes;
  final DateTime? bedtime;
  final DateTime? wakeTime;

  /// Subjective quality from 0 to 5.
  final int quality;
  final String? note;
  final DateTime createdAt;

  SleepLog copyWith({
    int? id,
    String? userId,
    DateTime? sleepDate,
    int? durationMinutes,
    DateTime? bedtime,
    DateTime? wakeTime,
    int? quality,
    String? note,
    DateTime? createdAt,
  }) {
    return SleepLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sleepDate: sleepDate ?? this.sleepDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      quality: quality ?? this.quality,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        sleepDate,
        durationMinutes,
        bedtime,
        wakeTime,
        quality,
        note,
        createdAt,
      ];
}
