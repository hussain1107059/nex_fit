import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../domain/entities/exercise_category.dart';
import '../../workout/widgets/workout_cover.dart';
import 'exercise_cover.dart';

/// Asset paths that were probed and do not exist, so we never retry them.
final Set<String> _missingAssets = <String>{};

/// Asset paths confirmed to exist (avoids repeated rootBundle loads).
final Set<String> _verifiedAssets = <String>{};

/// Converts an exercise name into an asset file name convention,
/// e.g. "Diamond Push-Ups" -> `diamond_push_ups.gif`.
@visibleForTesting
String exerciseAssetSlug(String name) {
  final StringBuffer buffer = StringBuffer();
  String previous = '_';
  for (final int code in name.toLowerCase().runes) {
    String ch = String.fromCharCode(code);
    if ((code >= 0x30 && code <= 0x39) ||
        (code >= 0x61 && code <= 0x7A)) {
      // keep [0-9a-z]
    } else if (code >= 0x0980 && code <= 0x09FF) {
      ch = '-'; // transliterate Bangla runs into separators
    } else {
      ch = '_';
    }
    if (ch == previous && (ch == '_' || ch == '-')) continue;
    buffer.write(ch);
    previous = ch;
  }
  return buffer.toString().replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Renders a moving visual for an exercise inside the player:
///
/// 1. The exercise [gifPath] / [imagePath] when set — bundled asset paths are
///    verified before use; http(s) URLs stream directly (GIFs animate).
/// 2. A bundled GIF following the naming convention
///    `assets/exercises/<name_slug>.gif`, so dropping correctly named files
///    into that folder lights exercises up with zero database changes.
/// 3. An always-available animated fallback: a breathing icon on a coloured
///    disc wrapped by a slowly orbiting highlight ring.
class ExerciseMotionView extends StatefulWidget {
  const ExerciseMotionView({
    super.key,
    required this.name,
    this.gifPath,
    this.imagePath,
    this.category,
    this.size = 160,
  });

  final String name;
  final String? gifPath;
  final String? imagePath;
  final ExerciseCategory? category;
  final double size;

  @override
  State<ExerciseMotionView> createState() => _ExerciseMotionViewState();
}

class _ExerciseMotionViewState extends State<ExerciseMotionView>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  );

  /// Resolved media source: an asset path or an http(s) URL.
  _MotionSource? _source;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(covariant ExerciseMotionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name ||
        oldWidget.gifPath != widget.gifPath ||
        oldWidget.imagePath != widget.imagePath) {
      _source = null;
      unawaited(_resolve());
    }
  }

  Future<void> _resolve() async {
    final List<String?> candidates = <String?>[
      widget.gifPath,
      widget.imagePath,
      if (widget.name.trim().isNotEmpty)
        'assets/exercises/${exerciseAssetSlug(widget.name)}.gif',
    ];
    for (final String? candidate in candidates) {
      final _MotionSource? resolved = await _probe(candidate);
      if (!mounted) return;
      if (resolved != null) {
        setState(() => _source = resolved);
        return;
      }
    }
  }

  Future<_MotionSource?> _probe(String? raw) async {
    if (raw == null || raw.trim().isEmpty) return null;
    final String path = raw.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return _MotionSource(path, isNetwork: true);
    }
    if (_verifiedAssets.contains(path)) return _MotionSource(path);
    if (_missingAssets.contains(path)) return null;
    try {
      await rootBundle.load(path);
      _verifiedAssets.add(path);
      return _MotionSource(path);
    } on FlutterError {
      _missingAssets.add(path);
      return null;
    } catch (_) {
      _missingAssets.add(path);
      return null;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _MotionSource? source = _source;
    if (source != null) {
      return ClipRRect(
        borderRadius: AppRadius.lgRadius,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: source.isNetwork
              ? Image.network(
                  source.path,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _buildAnimated(context),
                )
              : Image.asset(
                  source.path,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _buildAnimated(context),
                ),
        ),
      );
    }
    return _buildAnimated(context);
  }

  Widget _buildAnimated(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Color base = Color(
      widget.category?.colorValue ??
          workoutColorValueForName(widget.name),
    );
    final IconData glyph =
        workoutIconFromName(widget.name) ??
        exerciseCategoryIconFor(widget.category);
    final double discSize = widget.size * 0.74;

    if (reduceMotion) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: _MotionDisc(base: base, glyph: glyph, diameter: discSize),
        ),
      );
    }

    _pulse.repeat(reverse: true);
    _orbit.repeat();

    final Animation<double> breathe = CurvedAnimation(
      parent: _pulse,
      curve: Curves.easeInOut,
    );

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedBuilder(
            animation: _orbit,
            builder: (BuildContext context, Widget? child) =>
                RotationTransition(turns: _orbit, child: child),
            child: CustomPaint(
              painter: _OrbitRingPainter(color: base),
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: breathe,
              builder: (BuildContext context, Widget? child) =>
                  Transform.scale(scale: 0.95 + breathe.value * 0.08, child: child),
              child: _MotionDisc(base: base, glyph: glyph, diameter: discSize),
            ),
          ),
        ],
      ),
    );
  }
}

class _MotionSource {
  const _MotionSource(this.path, {this.isNetwork = false});

  final String path;
  final bool isNetwork;
}

class _MotionDisc extends StatelessWidget {
  const _MotionDisc({
    required this.base,
    required this.glyph,
    required this.diameter,
  });

  final Color base;
  final IconData glyph;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final Color foreground = Color.alphaBlend(
              base.withValues(alpha: 0.72),
              context.colorScheme.surface,
            ).computeLuminance() >
            0.5
        ? Colors.black87
        : Colors.white;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            base.withValues(alpha: 0.95),
            base.withValues(alpha: 0.65),
          ],
        ),
      ),
      child: Icon(glyph, size: diameter * 0.42, color: foreground),
    );
  }
}

/// Sweep-gradient rim that appears to orbit when rotated by the controller.
class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double shortest = size.shortestSide;
    final double inset = shortest * 0.06;

    final Rect rimRect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (shortest - inset * 2) / 2 + inset * 0.9,
    );
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = inset * 0.7
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 3.14,
        colors: <Color>[
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.85),
          color.withValues(alpha: 0.0),
        ],
        transform: const GradientRotation(-1.2),
      ).createShader(rimRect);

    canvas.drawArc(rimRect, 0, 6.2831, false, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
