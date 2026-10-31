import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/activity.dart';
import '../../../../l10n/app_localizations.dart';

/// Presentation metadata for each [ActivityType].
extension ActivityTypeStyle on ActivityType {
  String label(AppLocalizations l10n) => switch (this) {
    ActivityType.walking => l10n.activityWalking,
    ActivityType.running => l10n.activityRunning,
    ActivityType.cycling => l10n.activityCycling,
    ActivityType.swimming => l10n.activitySwimming,
  };

  IconData get icon => switch (this) {
    ActivityType.walking => Icons.directions_walk_rounded,
    ActivityType.running => Icons.directions_run_rounded,
    ActivityType.cycling => Icons.directions_bike_rounded,
    ActivityType.swimming => Icons.pool_rounded,
  };

  Color color(AppColors colors) => switch (this) {
    ActivityType.walking => colors.success,
    ActivityType.running => colors.warning,
    ActivityType.cycling => colors.info,
    ActivityType.swimming => colors.tertiary,
  };
}
