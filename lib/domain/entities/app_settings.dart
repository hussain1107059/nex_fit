import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// Per-user application preferences and daily targets.
class AppSettings extends Equatable {
  const AppSettings({
    this.id,
    required this.userId,
    this.theme,
    this.locale,
    this.units = Units.metric,
    this.dailyCalorieTarget,
    this.dailyWaterTargetMl,
    this.dailyStepTarget,
    this.notificationsEnabled = true,
    this.reminderEnabled = true,
    this.dataSyncEnabled = true,
    this.backupEnabled = true,
    this.lastBackupAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final String? theme;
  final String? locale;
  final Units units;
  final double? dailyCalorieTarget;
  final int? dailyWaterTargetMl;
  final int? dailyStepTarget;
  final bool notificationsEnabled;
  final bool reminderEnabled;
  final bool dataSyncEnabled;
  final bool backupEnabled;
  final DateTime? lastBackupAt;
  final DateTime updatedAt;

  AppSettings copyWith({
    int? id,
    String? userId,
    String? theme,
    String? locale,
    Units? units,
    double? dailyCalorieTarget,
    int? dailyWaterTargetMl,
    int? dailyStepTarget,
    bool? notificationsEnabled,
    bool? reminderEnabled,
    bool? dataSyncEnabled,
    bool? backupEnabled,
    DateTime? lastBackupAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      theme: theme ?? this.theme,
      locale: locale ?? this.locale,
      units: units ?? this.units,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      dailyWaterTargetMl: dailyWaterTargetMl ?? this.dailyWaterTargetMl,
      dailyStepTarget: dailyStepTarget ?? this.dailyStepTarget,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      dataSyncEnabled: dataSyncEnabled ?? this.dataSyncEnabled,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        theme,
        locale,
        units,
        dailyCalorieTarget,
        dailyWaterTargetMl,
        dailyStepTarget,
        notificationsEnabled,
        reminderEnabled,
        dataSyncEnabled,
        backupEnabled,
        lastBackupAt,
        updatedAt,
      ];
}
