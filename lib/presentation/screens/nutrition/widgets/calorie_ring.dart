import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular calorie progress ring with rounded gradient stroke.
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.value,
    required this.child,
    this.size = 168,
    this.strokeWidth = 14,
    this.trackColor,
  });

  /// Progress 0..1 (values above 1 render as a full ring).
  final double value;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CalorieRingPainter(
          value: value.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          trackColor: trackColor ?? Theme.of(context).colorScheme.outlineVariant,
          gradientColors: const <Color>[Color(0xFF0E9F6E), Color(0xFF22C55E)],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  _CalorieRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.trackColor,
    required this.gradientColors,
  });

  final double value;
  final double strokeWidth;
  final Color trackColor;
  final List<Color> gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double startAngle = -math.pi / 2;

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (value <= 0) return;

    final Paint progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: gradientColors).createShader(rect);
    canvas.drawArc(rect, startAngle, value * 2 * math.pi, false, progress);
  }

  @override
  bool shouldRepaint(_CalorieRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.gradientColors != gradientColors;
  }
}
