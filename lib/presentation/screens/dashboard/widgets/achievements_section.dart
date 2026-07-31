import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/dashboard_data.dart';
import 'section_header.dart';

/// Latest earned badge and current streak.
class AchievementsSection extends StatelessWidget {
  const AchievementsSection({super.key, required this.achievement});

  final DashboardAchievement achievement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: context.l10n.dashboardAchievements),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(child: _BadgeTile(achievement: achievement)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _StreakTile(achievement: achievement)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.achievement});

  final DashboardAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final String? name = achievement.badgeName;
    final AppColors appColors =
        context.isDarkMode ? AppColors.dark : AppColors.light;

    final Widget icon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: appColors.warning.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.emoji_events_rounded,
        color: appColors.warning,
      ),
    );

    final String title;
    final String? subtitle;
    if (name == null) {
      title = context.l10n.dashboardNoBadgeYet;
      subtitle = null;
    } else {
      title = name;
      subtitle = _earnedText(context);
    }

    return _TileContent(icon: icon, title: title, subtitle: subtitle);
  }

  String _earnedText(BuildContext context) {
    final DateTime? earnedAt = achievement.earnedAt;
    if (earnedAt == null) return context.l10n.dashboardEarnedOn;
    final String date = DateFormat('d MMM yyyy')
        .format(earnedAt.toLocal())
        .toBanglaDigits();
    return '${context.l10n.dashboardEarnedOn} $date';
  }
}

class _StreakTile extends StatelessWidget {
  const _StreakTile({required this.achievement});

  final DashboardAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final AppColors appColors =
        context.isDarkMode ? AppColors.dark : AppColors.light;
    return _TileContent(
      icon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: appColors.success.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.local_fire_department_rounded,
          color: appColors.success,
        ),
      ),
      title: '${achievement.currentStreak}'.toBanglaDigits(),
      subtitle: context.l10n.dashboardCurrentStreak,
    );
  }
}

class _TileContent extends StatelessWidget {
  const _TileContent({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Widget icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
