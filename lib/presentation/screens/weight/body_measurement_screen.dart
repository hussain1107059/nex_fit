import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/body_measurement.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/weight_providers.dart';
import 'widgets/body_measurement_tile.dart';
import 'widgets/measurement_sheets.dart';
import 'widgets/trend_line_chart.dart';

/// Body measurement records with a per-part circumference trend chart.
class BodyMeasurementScreen extends ConsumerWidget {
  const BodyMeasurementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final AsyncValue<List<BodyMeasurement>> async = ref.watch(
      bodyMeasurementsProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.bodyMeasurementTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showMeasurementSheet(context, ref, userId: user.id),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.measurementAddTitle),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(bodyMeasurementsProvider),
        ),
        data: (List<BodyMeasurement> measurements) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              if (measurements.isNotEmpty) ...[
                const _TrendSection(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.l10n.measurementHistory,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (measurements.isEmpty)
                _EmptyMeasurementsCard(userId: user.id)
              else
                for (final BodyMeasurement measurement in measurements)
                  BodyMeasurementTile(measurement: measurement),
            ],
          );
        },
      ),
    );
  }
}

class _TrendSection extends ConsumerWidget {
  const _TrendSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BodyMeasurement>> async = ref.watch(
      bodyMeasurementsProvider,
    );

    return async.maybeWhen(
      data: (List<BodyMeasurement> all) => _TrendContent(
        measurements: all,
        selected: ref.watch(selectedMeasurementProvider),
        onSelected: (MeasurementType type) {
          ref.read(selectedMeasurementProvider.notifier).state = type;
        },
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _TrendContent extends StatelessWidget {
  const _TrendContent({
    required this.measurements,
    required this.selected,
    required this.onSelected,
  });

  final List<BodyMeasurement> measurements;
  final MeasurementType selected;
  final ValueChanged<MeasurementType> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    final List<TrendPoint> points = <TrendPoint>[
      for (int i = 0; i < measurements.length; i++)
        if (selected.read(measurements[i]) != null)
          TrendPoint(
            x: i.toDouble(),
            y: selected.read(measurements[i])!,
            label: DateFormat('dd/MM')
                .format(measurements[i].measuredAt)
                .toBanglaDigits(),
            tooltip: '${selected.read(measurements[i])!.toStringAsFixed(1)} '
                '${l10n.dashboardCmUnit}',
          ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.measurementTrend,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<MeasurementType>(
              showSelectedIcon: false,
              segments: <ButtonSegment<MeasurementType>>[
                for (final MeasurementType type in MeasurementType.values)
                  ButtonSegment<MeasurementType>(
                    value: type,
                    label: Text(measurementLabel(context, type)),
                  ),
              ],
              selected: <MeasurementType>{selected},
              onSelectionChanged: (Set<MeasurementType> selection) {
                onSelected(selection.first);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (points.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  l10n.measurementTrendEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            TrendLineChart(
              points: points,
              color: theme.colorScheme.tertiary,
              height: 180,
            ),
        ],
      ),
    );
  }
}

class _EmptyMeasurementsCard extends ConsumerWidget {
  const _EmptyMeasurementsCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 48,
              color: context.colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.measurementNoMeasurements,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.measurementNoMeasurementsSubtitle,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () =>
                  showMeasurementSheet(context, ref, userId: userId),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.measurementAddTitle),
            ),
          ],
        ),
      ),
    );
  }
}
