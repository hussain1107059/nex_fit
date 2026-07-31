import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../extensions/context_extensions.dart';

/// A shimmering skeleton block used to indicate loading content.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: shape == BoxShape.circle ? height : height,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(radius)
            : null,
        color: context.colorScheme.onSurface.withValues(alpha: 0.08),
      ),
    );
  }
}

/// Wraps content in a [Shimmer] effect for skeleton loading screens.
class AppShimmer extends StatelessWidget {
  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.enabled = true,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Shimmer.fromColors(
      baseColor: baseColor ??
          context.colorScheme.onSurface.withValues(alpha: 0.10),
      highlightColor:
          highlightColor ??
          context.colorScheme.onSurface.withValues(alpha: 0.02),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}
