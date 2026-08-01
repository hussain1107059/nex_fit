import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/water_history.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/water_providers.dart';
import '../nutrition/widgets/history_bar_chart.dart';

/// Water history across daily / weekly / monthly / yearly windows.
class WaterHistoryScreen extends ConsumerWidget {
  const WaterHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WaterHistory> async = ref.watch(waterHistoryProvider);
    final int goal = ref.watch(waterGoalMlProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.waterHistory)),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(waterHistoryProvider),
        ),
        data: (WaterHistory history) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              const _PeriodSelector(),
              const SizedBox(height: AppSpacing.md),
              _SummaryRow(history: history),
              const SizedBox(height: AppSpacing.md),
              _ChartCard(history: history, goal: goal),
            ],
          );
        },
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final WaterHistoryPeriod current = ref.watch(waterHistoryPeriodProvider);

    final List<(WaterHistoryPeriod, String)> options = <(WaterHistoryPeriod, String)>[
      (WaterHistoryPeriod.daily, l10n.waterHistoryDaily),
      (WaterHistoryPeriod.weekly, l10n.waterHistoryWeekly),
      (WaterHistoryPeriod.monthly, l10n.waterHistoryMonthly),
      (WaterHistoryPeriod.yearly, l10n.waterHistoryYearly),
    ];

    return SegmentedButton<WaterHistoryPeriod>(
      showSelectedIcon: false,
      segments: <ButtonSegment<WaterHistoryPeriod>>[
        for (final (WaterHistoryPeriod period, String label) in options)
          ButtonSegment<WaterHistoryPeriod>(
            value: period,
            label: Text(label),
          ),
      ],
      selected: <WaterHistoryPeriod>{current},
      onSelectionChanged: (Set<WaterHistoryPeriod> selection) {
        ref.read(waterHistoryPeriodProvider.notifier).state =
            selection.first;
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.history});

  final WaterHistory history;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: l10n.waterHistoryTotal,
            value: history.totalMl.toString().toBanglaDigits(),
            icon: Icons.water_drop_rounded,
            color: theme.colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            label: l10n.waterHistoryAverage,
            value: history.averageMl.toString().toBanglaDigits(),
            icon: Icons.calculate_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            label: l10n.waterHistoryBest,
            value: history.bestMl.toString().toBanglaDigits(),
            icon: Icons.emoji_events_rounded,
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$label · ${context.l10n.dashboardMlUnit}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.history, required this.goal});

  final WaterHistory history;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (history.buckets.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            children: [
              Icon(
                Icons.history_rounded,
                size: 44,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.waterNoHistory,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.waterNoHistorySubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<HistoryBarData> bars = <HistoryBarData>[
      for (int i = 0; i < history.buckets.length; i++)
        HistoryBarData(
          label: _labelFor(history.period, history.buckets[i], i),
          value: history.buckets[i].intakeMl.toDouble(),
          color: theme.colorScheme.tertiary,
          target: goal > 0 ? goal.toDouble() : null,
        ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _titleFor(history),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          HistoryBarChart(bars: bars),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${l10n.waterHistoryLogged}: '
            '${history.loggedBuckets.toString().toBanglaDigits()} / '
            '${history.buckets.length.toString().toBanglaDigits()}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(
    WaterHistoryPeriod period,
    WaterHistoryBucket bucket,
    int index,
  ) {
    return switch (period) {
      WaterHistoryPeriod.daily =>
        bucket.start.day.toString().toBanglaDigits(),
      WaterHistoryPeriod.weekly =>
        'W${(index + 1).toString().toBanglaDigits()}',
      WaterHistoryPeriod.monthly =>
        bucket.start.month.toString().toBanglaDigits(),
      WaterHistoryPeriod.yearly => bucket.start.year.toString().toBanglaDigits(),
    };
  }

  String _titleFor(WaterHistory history) {
    final DateTime start = history.start;
    final DateTime end = history.end;
    return switch (history.period) {
      WaterHistoryPeriod.daily =>
        '${start.day.toString().toBanglaDigits()} – '
            '${end.day.toString().toBanglaDigits()} '
            '${_monthName(start.month)}',
      WaterHistoryPeriod.weekly =>
        '${_monthName(start.month)} ${start.year.toString().toBanglaDigits()}',
      WaterHistoryPeriod.monthly => start.year.toString().toBanglaDigits(),
      WaterHistoryPeriod.yearly =>
        '${start.year.toString().toBanglaDigits()} – '
            '${end.year.toString().toBanglaDigits()}',
    };
  }

  String _monthName(int month) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}
