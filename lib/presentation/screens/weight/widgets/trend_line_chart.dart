import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';

/// A single point of a trend line chart.
class TrendPoint {
  const TrendPoint({
    required this.x,
    required this.y,
    required this.label,
    required this.tooltip,
  });

  final double x;
  final double y;

  /// Short label rendered under the x axis.
  final String label;

  /// Text shown inside the touch tooltip.
  final String tooltip;
}

/// Smooth animated line chart (fl_chart) used by the weight and body
/// measurement trends.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.points,
    required this.color,
    this.height = 200,
  });

  final List<TrendPoint> points;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final List<FlSpot> spots = <FlSpot>[
      for (final TrendPoint point in points) FlSpot(point.x, point.y),
    ];

    final double rawMin = spots.map((FlSpot s) => s.y).reduce((a, b) => a < b ? a : b);
    final double rawMax = spots.map((FlSpot s) => s.y).reduce((a, b) => a > b ? a : b);
    final double span = (rawMax - rawMin).abs();
    final double padding = span == 0 ? rawMax * 0.05 + 0.5 : span * 0.18;
    final double minY = (rawMin - padding).floorToDouble();
    final double maxY = (rawMax + padding).ceilToDouble();

    final TextStyle axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 10,
    ) ??
        const TextStyle(fontSize: 10);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: points.first.x,
          maxX: points.last.x,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot spot) {
                  final int index = spot.x.round();
                  final TrendPoint point = points[index.clamp(
                    0,
                    points.length - 1,
                  )];
                  return LineTooltipItem(
                    point.tooltip,
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (double value) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      value.toStringAsFixed(0).toBanglaDigits(),
                      style: axisStyle,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: _labelInterval(points.length),
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.round();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      points[index].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: axisStyle,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (
                  FlSpot spot,
                  double xPercentage,
                  LineChartBarData bar,
                  int index,
                ) {
                  return FlDotCirclePainter(
                    radius: 3.5,
                    color: theme.colorScheme.surface,
                    strokeWidth: 2.5,
                    strokeColor: color,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Keeps the x labels readable: ~5 labels max across the width.
  double _labelInterval(int count) {
    if (count <= 1) return 1;
    final int step = (count / 5).ceil();
    return step.toDouble();
  }
}

/// Rounded container used to frame a trend chart inside a card.
class TrendChartCard extends StatelessWidget {
  const TrendChartCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLowest.withValues(
          alpha: 0.6,
        ),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
