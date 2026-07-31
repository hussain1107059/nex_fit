import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../extensions/context_extensions.dart';

/// Reusable rounded surface card with optional press feedback,
/// elevation and glass styling.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onPressed,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
    this.showShadow = true,
    this.glass = false,
    this.gradient,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadius? borderRadius;
  final bool showShadow;
  final bool glass;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? AppRadius.lgRadius;

    final Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: gradient,
        color: glass
            ? null
            : color ?? context.colorScheme.surface,
        boxShadow: showShadow ? AppShadows.soft : null,
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );

    if (onPressed == null) return surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: surface,
      ),
    );
  }
}
