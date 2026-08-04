import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/progress/fitness_score.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/progress_providers.dart';
import 'widgets/progress_widgets.dart';

/// Composite fitness score with its component breakdown.
class FitnessScoreScreen extends ConsumerWidget {
  const FitnessScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FitnessScore> async = ref.watch(fitnessScoreProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.progressScoreTitle)),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(fitnessScoreProvider),
        ),
        data: (FitnessScore score) => _ScoreContent(score: score),
      ),
    );
  }
}

class _ScoreContent extends StatelessWidget {
  const _ScoreContent({required this.score});

  final FitnessScore score;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors =
        AppColors.light;
    final Color color = _scoreColor(context, colors, score.score);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Center(
          child: ScoreRing(
            score: score.score,
            label: _scoreLabel(l10n, score.score),
            color: color,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.progressScoreBreakdown,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (score.metrics.isEmpty)
          AppCard(
            child: Text(
              l10n.progressEmptyTitle,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final FitnessScoreMetric metric in score.metrics) ...<Widget>[
            _MetricRow(metric: metric),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  Color _scoreColor(
    BuildContext context,
    AppColors colors,
    int value,
  ) {
    if (value >= 80) return colors.success;
    if (value >= 60) return colors.primary;
    if (value >= 40) return colors.warning;
    return colors.danger;
  }

  String _scoreLabel(AppLocalizations l10n, int value) {
    if (value >= 80) return l10n.progressScoreExcellent;
    if (value >= 60) return l10n.progressScoreGood;
    if (value >= 40) return l10n.progressScoreFair;
    if (value >= 20) return l10n.progressScoreNeedsWork;
    return l10n.progressScoreGettingStarted;
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});

  final FitnessScoreMetric metric;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors =
        AppColors.light;
    final Color color = _metricColor(colors, metric.key);

    return AppCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(_metricIcon(metric.key), size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _metricLabel(l10n, metric.key),
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: metric.score / 100,
                    minHeight: 7,
                    backgroundColor: color.withValues(alpha: 0.16),
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            metric.score.toString().toBanglaDigits(),
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _metricColor(AppColors colors, String key) {
    return switch (key) {
      'workout' => colors.primary,
      'consistency' => colors.success,
      'activity' => colors.info,
      'hydration' => colors.info,
      'sleep' => colors.tertiary,
      _ => colors.secondary,
    };
  }

  IconData _metricIcon(String key) {
    return switch (key) {
      'workout' => Icons.fitness_center_rounded,
      'consistency' => Icons.local_fire_department_rounded,
      'activity' => Icons.directions_walk_rounded,
      'hydration' => Icons.water_drop_rounded,
      'sleep' => Icons.bedtime_rounded,
      _ => Icons.restaurant_rounded,
    };
  }

  String _metricLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      'workout' => l10n.progressMetricWorkout,
      'consistency' => l10n.progressMetricConsistency,
      'activity' => l10n.progressMetricActivity,
      'hydration' => l10n.progressMetricHydration,
      'sleep' => l10n.progressMetricSleep,
      _ => l10n.progressMetricNutrition,
    };
  }
}
