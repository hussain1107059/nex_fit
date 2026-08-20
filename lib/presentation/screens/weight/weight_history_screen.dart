import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/weight_history.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/weight_providers.dart';
import 'widgets/trend_line_chart.dart';

/// Weight history across daily / weekly / monthly / yearly windows.
class WeightHistoryScreen extends ConsumerWidget {
  const WeightHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WeightHistory> async = ref.watch(weightHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.weightHistory)),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(weightHistoryProvider),
        ),
        data: (WeightHistory history) {
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
              _ChartCard(history: history),
              const SizedBox(height: AppSpacing.md),
              _BucketList(history: history),
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
    final WeightHistoryPeriod current = ref.watch(weightHistoryPeriodProvider);

    final List<(WeightHistoryPeriod, String)> options = <(WeightHistoryPeriod, String)>[
      (WeightHistoryPeriod.daily, l10n.weightHistoryDaily),
      (WeightHistoryPeriod.weekly, l10n.weightHistoryWeekly),
      (WeightHistoryPeriod.monthly, l10n.weightHistoryMonthly),
      (WeightHistoryPeriod.yearly, l10n.weightHistoryYearly),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<WeightHistoryPeriod>(
        showSelectedIcon: false,
        segments: <ButtonSegment<WeightHistoryPeriod>>[
          for (final (WeightHistoryPeriod period, String label) in options)
            ButtonSegment<WeightHistoryPeriod>(
              value: period,
              label: Text(label),
            ),
        ],
        selected: <WeightHistoryPeriod>{current},
        onSelectionChanged: (Set<WeightHistoryPeriod> selection) {
          ref.read(weightHistoryPeriodProvider.notifier).state = selection.first;
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.history});

  final WeightHistory history;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final double? start = history.startWeight;
    final double? latest = history.latestWeight;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: l10n.weightHistoryStart,
            value: start == null
                ? '—'
                : '${start.toStringAsFixed(1)} ${l10n.dashboardKgUnit}'
                      .toBanglaDigits(),
            icon: Icons.play_arrow_rounded,
            color: theme.colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            label: l10n.weightHistoryCurrent,
            value: latest == null
                ? '—'
                : '${latest.toStringAsFixed(1)} ${l10n.dashboardKgUnit}'
                      .toBanglaDigits(),
            icon: Icons.flag_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            label: l10n.weightHistoryChange,
            value: history.totalChange == 0
                ? '—'
                : '${history.totalChange.toStringAsFixed(1)} '
                      '${l10n.dashboardKgUnit}'.toBanglaDigits(),
            icon: history.totalChange <= 0
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: history.totalChange <= 0
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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
  const _ChartCard({required this.history});

  final WeightHistory history;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    final List<WeightHistoryBucket> filled = history.buckets
        .where((WeightHistoryBucket bucket) => bucket.entries > 0)
        .toList();

    if (filled.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 44,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.weightNoHistory,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.weightNoHistorySubtitle,
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

    final List<TrendPoint> points = <TrendPoint>[];
    for (int i = 0; i < history.buckets.length; i++) {
      final WeightHistoryBucket bucket = history.buckets[i];
      if (bucket.entries == 0) continue;
      points.add(
        TrendPoint(
          x: i.toDouble(),
          y: bucket.latestWeightKg,
          label: _labelFor(history.period, bucket, i),
          tooltip: '${bucket.latestWeightKg.toStringAsFixed(1)} '
              '${l10n.dashboardKgUnit}',
        ),
      );
    }

    return TrendChartCard(
      title: _titleFor(history, l10n),
      child: TrendLineChart(
        points: points,
        color: theme.colorScheme.tertiary,
        height: 200,
      ),
    );
  }

  String _labelFor(
    WeightHistoryPeriod period,
    WeightHistoryBucket bucket,
    int index,
  ) {
    return switch (period) {
      WeightHistoryPeriod.daily => bucket.start.day.toString().toBanglaDigits(),
      WeightHistoryPeriod.weekly => 'W${(index + 1).toString().toBanglaDigits()}',
      WeightHistoryPeriod.monthly => bucket.start.month.toString().toBanglaDigits(),
      WeightHistoryPeriod.yearly => bucket.start.year.toString().toBanglaDigits(),
    };
  }

  String _titleFor(WeightHistory history, AppLocalizations l10n) {
    final DateTime start = history.start;
    return switch (history.period) {
      WeightHistoryPeriod.daily =>
        '${start.day.toString().toBanglaDigits()} – '
            '${history.end.day.toString().toBanglaDigits()} '
            '${_monthName(l10n, start.month)}',
      WeightHistoryPeriod.weekly =>
        '${_monthName(l10n, start.month)} ${start.year.toString().toBanglaDigits()}',
      WeightHistoryPeriod.monthly => start.year.toString().toBanglaDigits(),
      WeightHistoryPeriod.yearly =>
        '${start.year.toString().toBanglaDigits()} – '
            '${history.end.year.toString().toBanglaDigits()}',
    };
  }

  String _monthName(AppLocalizations l10n, int month) {
    return localizedMonth(l10n, month);
  }
}

class _BucketList extends StatelessWidget {
  const _BucketList({required this.history});

  final WeightHistory history;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    final List<WeightHistoryBucket> filled = history.buckets
        .where((WeightHistoryBucket bucket) => bucket.entries > 0)
        .toList()
        .reversed
        .toList();

    if (filled.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${l10n.weightHistoryLogged}: '
            '${history.loggedBuckets.toString().toBanglaDigits()} / '
            '${history.buckets.length.toString().toBanglaDigits()}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < filled.length; i++)
            _BucketRow(bucket: filled[i], period: history.period),
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.bucket, required this.period});

  final WeightHistoryBucket bucket;
  final WeightHistoryPeriod period;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double change = bucket.changeKg;
    final Color changeColor =
        change <= 0 ? theme.colorScheme.primary : theme.colorScheme.error;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        change <= 0
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded,
        size: 18,
        color: changeColor,
      ),
      title: Text(
        '${bucket.latestWeightKg.toStringAsFixed(1)} '
        '${context.l10n.dashboardKgUnit}'.toBanglaDigits(),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        '${bucket.start.day.toString().toBanglaDigits()} '
        '${_monthName(context.l10n, bucket.start.month)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: change == 0
          ? Text(
              '—',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Text(
              '${change.abs().toStringAsFixed(1)} '
              '${context.l10n.dashboardKgUnit}'.toBanglaDigits(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: changeColor,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  String _monthName(AppLocalizations l10n, int month) {
    return localizedMonth(l10n, month);
  }
}
