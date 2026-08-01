import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/common_enums.dart';
import '../../../../domain/entities/dashboard_data.dart';
import 'section_header.dart';

/// Today's scheduled reminders.
class RemindersSection extends StatelessWidget {
  const RemindersSection({super.key, required this.reminders});

  final List<DashboardReminder> reminders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: context.l10n.dashboardUpcomingReminders),
        if (reminders.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    size: 34,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.l10n.dashboardNoReminders,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    context.l10n.dashboardNoRemindersSubtitle,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (int i = 0; i < reminders.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 64,
                      endIndent: AppSpacing.md,
                      color: context.colorScheme.outlineVariant,
                    ),
                  _ReminderTile(reminder: reminders[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder});

  final DashboardReminder reminder;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.isDarkMode ? AppColors.dark : AppColors.light;
    final (IconData icon, Color color) = switch (reminder.reminderType) {
      ReminderType.water => (Icons.water_drop_rounded, colors.info),
      ReminderType.step => (Icons.directions_walk_rounded, colors.success),
      ReminderType.meal => (Icons.restaurant_rounded, colors.warning),
      ReminderType.workout => (Icons.fitness_center_rounded, colors.primary),
      ReminderType.weight => (Icons.monitor_weight_rounded, colors.tertiary),
      ReminderType.medicine => (Icons.medication_rounded, colors.danger),
      ReminderType.sleep => (Icons.bedtime_rounded, colors.tertiary),
      ReminderType.custom => (
        Icons.notifications_active_rounded,
        colors.scheme.onSurfaceVariant,
      ),
    };

    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        reminder.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Text(
        _formatTime(reminder.time),
        style: context.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _formatTime(String hhmm) {
    final List<String> parts = hhmm.split(':');
    if (parts.length != 2) return hhmm.toBanglaDigits();
    final int hour = int.tryParse(parts[0]) ?? 0;
    final int minute = int.tryParse(parts[1]) ?? 0;
    final DateTime time = DateTime(0, 1, 1, hour, minute);
    return DateFormat('h:mm a').format(time).toBanglaDigits();
  }
}
