import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../domain/entities/progress/goal_progress.dart';
import '../../../../domain/entities/progress/personal_record.dart';
import '../../../../domain/entities/progress/report_period.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/progress_providers.dart';
import '../../dashboard/widgets/goal_ring.dart';

/// Horizontal choice-chip row selecting the report window, plus a custom
/// date range picker when [ReportPeriod.custom] is selected.
class PeriodFilter extends ConsumerWidget {
  const PeriodFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ReportPeriod period = ref.watch(progressPeriodProvider);

    final List<(ReportPeriod, String)> entries = <(ReportPeriod, String)>[
      (ReportPeriod.today, l10n.progressFilterToday),
      (ReportPeriod.last7Days, l10n.progressFilterLast7Days),
      (ReportPeriod.last30Days, l10n.progressFilterLast30Days),
      (ReportPeriod.last90Days, l10n.progressFilterLast90Days),
      (ReportPeriod.thisYear, l10n.progressFilterThisYear),
      (ReportPeriod.custom, l10n.progressFilterCustom),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final (ReportPeriod value, String label) in entries)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: period == value,
                    onSelected: (bool _) {
                      ref.read(progressPeriodProvider.notifier).state = value;
                      if (value != ReportPeriod.custom) {
                        ref
                            .read(progressCustomRangeProvider.notifier)
                            .state = null;
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        if (period == ReportPeriod.custom) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const _CustomRangeButton(),
        ],
      ],
    );
  }
}

class _CustomRangeButton extends ConsumerWidget {
  const _CustomRangeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DateTimeRange? range = ref.watch(progressCustomRangeProvider);
    final DateTime now = DateTime.now();

    return OutlinedButton.icon(
      onPressed: () async {
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 5),
          lastDate: now,
          initialDateRange:
              range ??
              DateTimeRange(
                start: now.subtract(const Duration(days: 29)),
                end: now,
              ),
        );
        if (picked != null) {
          ref.read(progressCustomRangeProvider.notifier).state = picked;
        }
      },
      icon: const Icon(Icons.date_range_rounded, size: 18),
      label: Text(
        range == null
            ? l10n.progressSelectRange
            : '${_shortDate(range.start)} – ${_shortDate(range.end)}',
      ),
    );
  }

  String _shortDate(DateTime date) {
    return '${date.day.toString().toBanglaDigits()} '
        '${_monthName(date.month)} '
        '${date.year.toString().toBanglaDigits()}';
  }

  String _monthName(int month) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}

/// AppCard with a bold section title and optional trailing action.
class ProgressSectionCard extends StatelessWidget {
  const ProgressSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) ...<Widget>[trailing!],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// A single goal with a progress bar and an animated completion ring.
class GoalProgressTile extends StatelessWidget {
  const GoalProgressTile({super.key, required this.goal});

  final GoalProgress goal;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors =
        AppColors.light;
    final Color color = _goalColor(colors, goal.kind);
    final IconData icon = _goalIcon(goal.kind);
    final String title = _goalTitle(l10n, goal.kind);
    final String unit = _unitLabel(l10n, goal.unit);

    return AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (goal.hasTarget)
                  ClipRRect(
                    borderRadius: AppRadius.pillRadius,
                    child: LinearProgressIndicator(
                      value: goal.fraction,
                      minHeight: 8,
                      backgroundColor: color.withValues(alpha: 0.16),
                      color: color,
                    ),
                  )
                else
                  Text(
                    l10n.progressGoalNotSet,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Text(
                      '${_formatValue(goal.current, goal.unit)} $unit'
                          .toBanglaDigits(),
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (goal.hasTarget)
                      Text(
                        '${goal.percent.round().toString().toBanglaDigits()}%',
                        style: context.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                  ],
                ),
                if (goal.hasTarget && goal.daysLeft > 0) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.progressDaysLeft} '
                    '${goal.daysLeft.toString().toBanglaDigits()}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          GoalRing(
            progress: goal.fraction,
            valueText: goal.hasTarget
                ? '${goal.percent.round().toString().toBanglaDigits()}%'
                : '—',
            label: l10n.progressCompletion,
            icon: Icons.check_circle_rounded,
            color: color,
            targetText: goal.hasTarget
                ? '${_formatValue(goal.target, goal.unit)} $unit'.toBanglaDigits()
                : null,
            goalSet: goal.hasTarget,
          ),
        ],
      ),
    );
  }
}

/// A single personal record with its value and date.
class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.record});

  final PersonalRecord record;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors =
        AppColors.light;
    final Color color = _recordColor(colors, record.kind);

    return AppCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(_recordIcon(record.kind), size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _recordTitle(l10n, record.kind),
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_recordDate(l10n, record) != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    _recordDate(l10n, record)!,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${_formatValue(record.value ?? 0, record.unit)} '
            '${_unitLabel(l10n, record.unit)}'.toBanglaDigits(),
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Large animated ring used for the fitness score.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.label,
    required this.color,
    this.size = 150,
  });

  final int score;
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: score / 100),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? child) {
            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 13,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor:
                        context.colorScheme.surfaceContainerHighest,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          score.toString().toBanglaDigits(),
                          style: context.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        Text(
                          l10nProgressScoreShort(context),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String l10nProgressScoreShort(BuildContext context) {
  return context.l10n.progressScore;
}

// --- mappings -------------------------------------------------------------

IconData _goalIcon(GoalKind kind) {
  return switch (kind) {
    GoalKind.weight => Icons.monitor_weight_rounded,
    GoalKind.workout => Icons.fitness_center_rounded,
    GoalKind.calories => Icons.local_fire_department_rounded,
    GoalKind.water => Icons.water_drop_rounded,
    GoalKind.steps => Icons.directions_walk_rounded,
    GoalKind.sleep => Icons.bedtime_rounded,
  };
}

Color _goalColor(AppColors colors, GoalKind kind) {
  return switch (kind) {
    GoalKind.weight => colors.tertiary,
    GoalKind.workout => colors.primary,
    GoalKind.calories => colors.secondary,
    GoalKind.water => colors.info,
    GoalKind.steps => colors.success,
    GoalKind.sleep => colors.tertiary,
  };
}

String _goalTitle(AppLocalizations l10n, GoalKind kind) {
  return switch (kind) {
    GoalKind.weight => l10n.progressGoalWeight,
    GoalKind.workout => l10n.progressGoalWorkout,
    GoalKind.calories => l10n.progressGoalCalories,
    GoalKind.water => l10n.progressGoalWater,
    GoalKind.steps => l10n.progressGoalSteps,
    GoalKind.sleep => l10n.progressGoalSleep,
  };
}

IconData _recordIcon(RecordKind kind) {
  return switch (kind) {
    RecordKind.longestWorkout => Icons.timer_rounded,
    RecordKind.highestCalories => Icons.local_fire_department_rounded,
    RecordKind.fastestWorkout => Icons.bolt_rounded,
    RecordKind.longestStreak => Icons.emoji_events_rounded,
    RecordKind.bestWeek => Icons.date_range_rounded,
    RecordKind.bestMonth => Icons.calendar_month_rounded,
    RecordKind.mostActiveDay => Icons.trending_up_rounded,
  };
}

Color _recordColor(AppColors colors, RecordKind kind) {
  return switch (kind) {
    RecordKind.longestWorkout => colors.primary,
    RecordKind.highestCalories => colors.secondary,
    RecordKind.fastestWorkout => colors.info,
    RecordKind.longestStreak => colors.success,
    RecordKind.bestWeek => colors.tertiary,
    RecordKind.bestMonth => colors.tertiary,
    RecordKind.mostActiveDay => colors.warning,
  };
}

String _recordTitle(AppLocalizations l10n, RecordKind kind) {
  return switch (kind) {
    RecordKind.longestWorkout => l10n.progressRecordLongestWorkout,
    RecordKind.highestCalories => l10n.progressRecordHighestCalories,
    RecordKind.fastestWorkout => l10n.progressRecordFastestWorkout,
    RecordKind.longestStreak => l10n.progressRecordLongestStreak,
    RecordKind.bestWeek => l10n.progressRecordBestWeek,
    RecordKind.bestMonth => l10n.progressRecordBestMonth,
    RecordKind.mostActiveDay => l10n.progressRecordMostActiveDay,
  };
}

String? _recordDate(AppLocalizations l10n, PersonalRecord record) {
  switch (record.kind) {
    case RecordKind.longestWorkout:
    case RecordKind.highestCalories:
    case RecordKind.fastestWorkout:
    case RecordKind.longestStreak:
      final DateTime? date = record.occurredOn;
      if (date == null) return null;
      return '${l10n.progressOnDate} ${_fullDate(date)}';
    case RecordKind.bestWeek:
      final DateTime? week = record.weekStart;
      if (week == null) return null;
      return '${l10n.progressWeekOf} ${_fullDate(week)}';
    case RecordKind.bestMonth:
      final DateTime? month = record.monthStart;
      if (month == null) return null;
      return _monthName(month.month);
    case RecordKind.mostActiveDay:
      final DateTime? day = record.activeDay;
      if (day == null) return null;
      return _fullDate(day);
  }
}

String _fullDate(DateTime date) {
  return '${date.day.toString().toBanglaDigits()} '
      '${_monthName(date.month)} '
      '${date.year.toString().toBanglaDigits()}';
}

String _monthName(int month) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return months[month - 1];
}

/// Concise localised unit label keyed by the semantic token used in exports.
String _unitLabel(AppLocalizations l10n, String? unit) {
  return switch (unit) {
    'kcal' => l10n.progressUnitKcal,
    'kg' => l10n.progressUnitKg,
    'ml' => l10n.progressUnitMl,
    'min' => l10n.progressUnitMin,
    'days' => l10n.progressUnitDays,
    'steps' => l10n.progressUnitSteps,
    'workouts' => l10n.progressUnitWorkouts,
    'hrs' => l10n.progressUnitHours,
    _ => unit ?? '',
  };
}

/// Formats a value according to its unit (counts without decimals).
String _formatValue(double value, String? unit) {
  if (unit == 'steps' ||
      unit == 'workouts' ||
      unit == 'days' ||
      unit == 'ml') {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
