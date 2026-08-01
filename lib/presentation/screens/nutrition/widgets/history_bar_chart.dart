import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// A single bar of the history chart.
class HistoryBarData {
  const HistoryBarData({
    required this.label,
    required this.value,
    required this.color,
    this.target,
  });

  final String label;
  final double value;
  final Color color;

  /// Optional goal line drawn across the chart.
  final double? target;
}

/// Vertical bar chart used by the nutrition history screen.
class HistoryBarChart extends StatelessWidget {
  const HistoryBarChart({
    super.key,
    required this.bars,
    this.height = 180,
  });

  final List<HistoryBarData> bars;
  final double height;

  double get _maxValue {
    double max = 0;
    for (final HistoryBarData bar in bars) {
      if (bar.value > max) max = bar.value;
      if (bar.target != null && bar.target! > max) max = bar.target!;
    }
    return max <= 0 ? 1 : max;
  }

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final double max = _maxValue;

    return SizedBox(
      height: height + 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CustomPaint(
              painter: _BarChartPainter(
                bars: bars,
                max: max,
                targetColor: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bars
                .map(
                  (HistoryBarData bar) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: Text(
                        bar.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.bars, required this.max, required this.targetColor});

  final List<HistoryBarData> bars;
  final double max;
  final Color targetColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Goal lines.
    for (final HistoryBarData bar in bars) {
      if (bar.target == null || bar.target! <= 0) continue;
      final double y = height - (bar.target! / max) * height;
      final Paint line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = targetColor.withValues(alpha: 0.6);
      canvas.drawLine(Offset(0, y), Offset(width, y), line);
      break; // one line is enough
    }

    final double barWidth = width / bars.length;
    const double gap = 8;
    for (int index = 0; index < bars.length; index++) {
      final HistoryBarData bar = bars[index];
      final double x = index * barWidth;
      final double fraction = max <= 0 ? 0 : (bar.value / max).clamp(0.0, 1.0);
      final double barHeight = height * fraction;
      if (barHeight <= 0) continue;

      final double left = x + gap;
      final double right = x + barWidth - gap;
      final RRect rrect = RRect.fromRectAndCorners(
        Rect.fromLTRB(left, height - barHeight, right, height),
        topLeft: Radius.circular(AppRadius.md),
        topRight: Radius.circular(AppRadius.md),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              bar.color.withValues(alpha: 0.9),
              bar.color.withValues(alpha: 0.55),
            ],
          ).createShader(
            Rect.fromLTRB(left, height - barHeight, right, height),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) {
    return oldDelegate.bars != bars ||
        oldDelegate.max != max ||
        oldDelegate.targetColor != targetColor;
  }
}

