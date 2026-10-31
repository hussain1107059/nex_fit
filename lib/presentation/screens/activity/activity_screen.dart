import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/activity_metrics.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/empty_widget.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/activity.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/activity_providers.dart';
import '../../router/app_router.dart';
import '../dashboard/widgets/section_header.dart';
import 'widgets/activity_type_style.dart';

/// Activity tracker home: lifetime stats, activity picker and recent sessions.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ActivityStats> stats = ref.watch(activityStatsProvider);
    final AsyncValue<List<ActivitySession>> history = ref.watch(
      activityHistoryProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activityTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activityStatsProvider);
          ref.invalidate(activityHistoryProvider);
          await ref.read(activityHistoryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            stats.maybeWhen(
              data: (ActivityStats value) => _StatsCard(stats: value),
              orElse: () => const SizedBox(
                height: 150,
                child: LoadingWidget(compact: true),
              ),
            ),
            SectionHeader(title: l10n.activityChoose),
            _TypePicker(
              onSelected: (ActivityType type) =>
                  context.push(AppRoutes.activityTrack, extra: type),
            ),
            SectionHeader(title: l10n.activityRecent),
            history.when(
              data: (List<ActivitySession> sessions) =>
                  _HistoryList(sessions: sessions),
              error: (Object error, StackTrace stackTrace) => ErrorWidget(
                title: l10n.dashboardNoActivity,
                onRetry: () => ref.invalidate(activityHistoryProvider),
              ),
              loading: () =>
                  const SizedBox(height: 160, child: LoadingWidget()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final ActivityStats stats;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppCard(
      gradient: LinearGradient(
        colors: <Color>[
          context.colorScheme.primary,
          context.colorScheme.tertiary,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.route_rounded, color: Colors.white, size: 20),
              AppSpacing.xs.widthSpace,
              Text(
                l10n.activitySummary,
                style: context.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          AppSpacing.md.heightSpace,
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              _Metric(
                icon: Icons.straighten_rounded,
                label: l10n.activityTotalDistance,
                value:
                    '${ActivityMetrics.formatDistanceKm(stats.totalDistanceMeters).toBanglaDigits()} ${l10n.activityKm}',
              ),
              _Metric(
                icon: Icons.timer_outlined,
                label: l10n.activityTotalTime,
                value: ActivityMetrics.formatDurationShort(
                  stats.totalDurationSeconds,
                ).toBanglaDigits(),
              ),
              _Metric(
                icon: Icons.local_fire_department_rounded,
                label: l10n.activityCalories,
                value: stats.totalCalories.round().toString().toBanglaDigits(),
              ),
              _Metric(
                icon: Icons.bolt_rounded,
                label: l10n.activitySessions,
                value: stats.totalSessions.toString().toBanglaDigits(),
              ),
            ],
          ),
          if (stats.totalSessions == 0) ...<Widget>[
            AppSpacing.md.heightSpace,
            Text(
              l10n.activityGpsHint,
              style: context.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          AppSpacing.xs.widthSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.onSelected});

  final ValueChanged<ActivityType> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = AppColors.light;
    final List<ActivityType> types = ActivityType.values;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = context.isWide ? 4 : 2;
        final double spacing = AppSpacing.sm;
        final double cell =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final ActivityType type in types)
              SizedBox(
                width: cell,
                child: AppCard(
                  onPressed: () => onSelected(type),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: type.color(colors).withValues(alpha: 0.14),
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Icon(
                          type.icon,
                          color: type.color(colors),
                          size: 24,
                        ),
                      ),
                      AppSpacing.sm.heightSpace,
                      Text(
                        type.label(l10n),
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AppSpacing.xxs.heightSpace,
                      Text(
                        l10n.activityStart,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.sessions});

  final List<ActivitySession> sessions;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (sessions.isEmpty) {
      return SizedBox(
        height: 240,
        child: EmptyWidget(
          icon: Icons.route_rounded,
          title: l10n.activityNoHistory,
          subtitle: l10n.activityNoHistorySubtitle,
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (final ActivitySession session in sessions) ...<Widget>[
          _HistoryTile(session: session),
          AppSpacing.xs.heightSpace,
        ],
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.session});

  final ActivitySession session;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = AppColors.light;
    final Color accent = session.type.color(colors);
    final String time = DateFormat(
      'h:mm a',
    ).format(session.startedAt).toBanglaDigits();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      onPressed: session.id == null
          ? null
          : () => context.push(AppRoutes.activityDetailPath(session.id!)),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(session.type.icon, color: accent),
          ),
          AppSpacing.sm.widthSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.type.label(l10n),
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.xxs.heightSpace,
                Text(
                  '${formatLocalizedDate(session.startedAt, l10n)}, $time',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${ActivityMetrics.formatDistanceKm(session.distanceMeters).toBanglaDigits()} ${l10n.activityKm}',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ActivityMetrics.formatDurationShort(
                  session.durationSeconds,
                ).toBanglaDigits(),
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
