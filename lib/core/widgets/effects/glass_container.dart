import 'dart:ui';

import 'package:flutter/material.dart';

import '../../extensions/context_extensions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// A frosted glass surface built on [BackdropFilter].
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.md)),
    this.blur = 14,
    this.opacity = 0.55,
    this.border,
    this.padding,
    this.margin,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final double opacity;
  final BorderSide? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.isDarkMode ? AppColors.dark : AppColors.light;
    final BorderSide effectiveBorder =
        border ??
        BorderSide(
          color: colors.scheme.onSurface.withValues(alpha: 0.06),
        );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.fromBorderSide(effectiveBorder),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: colors.glassColor.withValues(alpha: opacity),
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
