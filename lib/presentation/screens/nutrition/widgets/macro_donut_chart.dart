import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A slice of the macro donut chart.
class MacroSlice {
  const MacroSlice({required this.value, required this.color, required this.label});

  final double value;
  final Color color;
  final String label;
}

/// Donut chart that visualises the protein/carb/fat split of the day.
class MacroDonutChart extends StatelessWidget {
  const MacroDonutChart({
    super.key,
    required this.slices,
    required this.centerTitle,
    required this.centerSubtitle,
    this.size = 180,
  });

  final List<MacroSlice> slices;
  final String centerTitle;
  final String centerSubtitle;
  final double size;

  double get _total => slices.fold(0, (double sum, MacroSlice slice) => sum + slice.value);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double total = _total;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(slices: slices, total: total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                centerSubtitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.total});

  final List<MacroSlice> slices;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 24;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double strokeWidth = 22;
    const double gap = 0.06; // radians between segments

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.black.withValues(alpha: 0.05);
    canvas.drawCircle(center, radius, track);

    double sweepStart = -math.pi / 2;
    for (final MacroSlice slice in slices) {
      if (slice.value <= 0) continue;
      final double fraction = total <= 0 ? 0 : slice.value / total;
      final double sweep = fraction * 2 * math.pi - gap;
      if (sweep <= 0.01) continue;

      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;
      canvas.drawArc(rect, sweepStart + gap / 2, sweep, false, paint);
      sweepStart += fraction * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) {
    if (oldDelegate.total != total) return true;
    if (oldDelegate.slices.length != slices.length) return true;
    for (int index = 0; index < slices.length; index++) {
      if (oldDelegate.slices[index].value != slices[index].value ||
          oldDelegate.slices[index].color != slices[index].color) {
        return true;
      }
    }
    return false;
  }
}
