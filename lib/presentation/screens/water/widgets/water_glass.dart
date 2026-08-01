import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated water glass that fills up to [ratio] with a moving sine wave.
///
/// The glass keeps a fixed aspect ratio; the water surface oscillates gently
/// while the fill level animates whenever [ratio] changes.
class WaterGlass extends StatefulWidget {
  const WaterGlass({super.key, required this.ratio, this.size = 180});

  /// Fill level between 0 and 1.
  final double ratio;

  /// Square edge length used to size the glass.
  final double size;

  @override
  State<WaterGlass> createState() => _WaterGlassState();
}

class _WaterGlassState extends State<WaterGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _wave,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            painter: _WaterGlassPainter(
              ratio: widget.ratio,
              progress: _wave.value,
              scheme: scheme,
            ),
          );
        },
      ),
    );
  }
}

class _WaterGlassPainter extends CustomPainter {
  _WaterGlassPainter({
    required this.ratio,
    required this.progress,
    required this.scheme,
  });

  final double ratio;
  final double progress;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Glass body: rounded rectangle slightly inset, drawn as an outline.
    final Rect glassRect = Rect.fromLTWH(
      width * 0.10,
      height * 0.10,
      width * 0.80,
      height * 0.80,
    );
    final RRect glass = RRect.fromRectAndCorners(
      glassRect,
      topLeft: Radius.circular(width * 0.14),
      topRight: Radius.circular(width * 0.14),
      bottomLeft: Radius.circular(width * 0.06),
      bottomRight: Radius.circular(width * 0.06),
    );

    // Subtle glass tint behind the water.
    canvas.drawRRect(
      glass,
      Paint()
        ..color = scheme.primaryContainer.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );

    // Water fill, clipped to the glass.
    canvas.save();
    canvas.clipPath(Path()..addRRect(glass));

    final double fillTop =
        glassRect.bottom - (glassRect.height * ratio.clamp(0.0, 1.0));
    final Rect fillRect = Rect.fromLTRB(
      glassRect.left,
      fillTop,
      glassRect.right,
      glassRect.bottom,
    );

    final Paint water = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          scheme.tertiary.withValues(alpha: 0.85),
          scheme.tertiary,
          scheme.primary.withValues(alpha: 0.95),
        ],
      ).createShader(fillRect);
    canvas.drawRect(fillRect, water);

    // Animated wave surface.
    final Path wave = _wavePath(glassRect, fillTop, progress);
    canvas.drawPath(
      wave,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      _wavePath(glassRect, fillTop, progress, phaseOffset: 0.5),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    // A couple of rising bubbles.
    _drawBubble(canvas, glassRect, progress);
    _drawBubble(canvas, glassRect, progress + 0.33);
    canvas.restore();

    // Glass outline on top of the water.
    canvas.drawRRect(
      glass,
      Paint()
        ..color = scheme.tertiary.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.028,
    );
  }

  Path _wavePath(Rect glass, double baseY, double progress, {double phaseOffset = 0}) {
    final Path path = Path()..moveTo(glass.left, baseY);
    const int segments = 12;
    final double segmentWidth = glass.width / segments;
    for (int i = 0; i <= segments; i++) {
      final double x = glass.left + (i * segmentWidth);
      final double phase =
          (i / segments) * math.pi * 2 + (progress + phaseOffset) * math.pi * 2;
      final double y = baseY + math.sin(phase) * (glass.height * 0.03);
      path.lineTo(x, y);
    }
    path
      ..lineTo(glass.right, glass.bottom)
      ..lineTo(glass.left, glass.bottom)
      ..close();
    return path;
  }

  void _drawBubble(Canvas canvas, Rect glass, double t) {
    final double cycle = (t * 2) % 1;
    final double x = glass.left + glass.width * (0.25 + 0.5 * cycle);
    final double y =
        glass.bottom - (glass.height * (0.25 + (cycle * 0.45)));
    final double radius = glass.width * 0.03;
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );
  }

  @override
  bool shouldRepaint(_WaterGlassPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.progress != progress ||
        oldDelegate.scheme != scheme;
  }
}
