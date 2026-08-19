import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/dashboard_data.dart';
import 'section_header.dart';

/// Four weekly mini charts: calories, weight, water and workout minutes.
class WeeklyStatsSection extends StatelessWidget {
  const WeeklyStatsSection({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.light;
    final String l10nKg = context.l10n.dashboardKgUnit;

    final List<Widget> cards = <Widget>[
      _ChartCard(
        title: context.l10n.dashboardCaloriesBurned,
        points: data.weeklyCalories,
        color: colors.primary,
        valueFormat: (double v) => v.round().toString(),
      ),
      _ChartCard(
        title: context.l10n.dashboardWeight,
        points: data.weeklyWeight,
        color: colors.tertiary,
        valueFormat: (double v) =>
            v == 0 ? '—' : '${v.toStringAsFixed(1)} $l10nKg',
        emptyMessage: context.l10n.dashboardNoWeightData,
      ),
      _ChartCard(
        title: context.l10n.dashboardWater,
        points: data.weeklyWater,
        color: colors.info,
        valueFormat: (double v) => v.round().toString(),
      ),
      _ChartCard(
        title: context.l10n.dashboardWorkoutMinutes,
        points: data.weeklyWorkout,
        color: colors.warning,
        valueFormat: (double v) => v.round().toString(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: context.l10n.dashboardWeeklyStats),
        // Fixed mainAxisExtent (not childAspectRatio) so a chart card can
        // never overflow on narrow screens or with larger text scales; the
        // extent grows with the text scale factor.
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisExtent: _cellExtent(context),
          ),
          itemCount: cards.length,
          itemBuilder: (BuildContext context, int index) => cards[index],
        ),
      ],
    );
  }

  double _cellExtent(BuildContext context) {
    final double factor = MediaQuery.textScalerOf(context).scale(1);
    return 132 * factor + 26;
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.points,
    required this.color,
    required this.valueFormat,
    this.emptyMessage,
  });

  final String title;
  final List<WeeklyStatPoint> points;
  final Color color;
  final String Function(double value) valueFormat;
  final String? emptyMessage;

  bool get _isEmpty => points.every((WeeklyStatPoint p) => p.value == 0);

  @override
  Widget build(BuildContext context) {
    final double total = points.fold(
      0.0,
      (double sum, WeeklyStatPoint p) => sum + p.value,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!_isEmpty)
                  Text(
                    valueFormat(total).toBanglaDigits(),
                    style: context.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_isEmpty && emptyMessage != null)
              Expanded(
                child: Center(
                  child: Text(
                    emptyMessage!,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              _WeeklyBarChart(points: points, color: color),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.points, required this.color});

  final List<WeeklyStatPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 56,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarChartPainter(points: points, color: color),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          children: [
            for (final WeeklyStatPoint point in points)
              Expanded(
                child: Text(
                  DateFormat('E').format(point.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.points, required this.color});

  final List<WeeklyStatPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double maxValue = points.fold(
      0.0,
      (double max, WeeklyStatPoint p) => p.value > max ? p.value : max,
    );

    final Paint baselinePaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      baselinePaint,
    );

    if (maxValue <= 0) return;

    final int count = points.length;
    final double slot = size.width / count;
    final double barWidth = slot * 0.5;

    for (int i = 0; i < count; i++) {
      final double value = points[i].value;
      final double barHeight = (size.height - 1) * (value / maxValue);
      final double left = slot * i + (slot - barWidth) / 2;
      final double top = size.height - 1 - barHeight;

      final Paint barPaint = Paint()
        ..color = i == count - 1 ? color : color.withValues(alpha: 0.45);
      final RRect bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(bar, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.points != points;
  }
}
