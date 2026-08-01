import 'package:flutter/material.dart';

/// Central colour palette for NexFit.
/// Contains the full Material 3 [ColorScheme] plus semantic and
/// brand-gradation colours used across the design system.
class AppColors {
  const AppColors._({
    required this.scheme,
    required this.success,
    required this.warning,
    required this.info,
    required this.danger,
    required this.brandGradient,
    required this.glassColor,
  });

  final ColorScheme scheme;
  final Color success;
  final Color warning;
  final Color info;
  final Color danger;
  final List<Color> brandGradient;
  final Color glassColor;

  Color get primary => scheme.primary;
  Color get onPrimary => scheme.onPrimary;
  Color get secondary => scheme.secondary;
  Color get tertiary => scheme.tertiary;
  Color get background => scheme.surfaceContainerLowest;
  Color get surface => scheme.surface;
  Color get surfaceVariant => scheme.surfaceContainerHighest;
  Color get onSurface => scheme.onSurface;

  /// Builds an [AppColors] from an arbitrary [ColorScheme], used when the
  /// user enables Material You dynamic colour on Android 12+.
  factory AppColors.fromScheme(ColorScheme scheme) {
    final bool dark = scheme.brightness == Brightness.dark;
    return AppColors._(
      scheme: scheme,
      success: dark ? const Color(0xFF34D399) : const Color(0xFF22C55E),
      warning: dark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
      info: dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
      danger: scheme.error,
      brandGradient: dark
          ? [scheme.primary, scheme.tertiary, scheme.secondary]
          : [scheme.primary, scheme.secondary, scheme.tertiary],
      glassColor: dark
          ? const Color(0x990F171F)
          : const Color(0xE6FFFFFF),
    );
  }

  static const AppColors light = AppColors._(
    scheme: ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF0E9F6E),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFC9F5E0),
      onPrimaryContainer: Color(0xFF062E21),
      secondary: Color(0xFFF97316),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFFE5D4),
      onSecondaryContainer: Color(0xFF3A1B06),
      tertiary: Color(0xFF6D5BD0),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFE5E0FA),
      onTertiaryContainer: Color(0xFF1E1640),
      error: Color(0xFFE5484D),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDADC),
      onErrorContainer: Color(0xFF5C1115),
      surfaceContainerLowest: Color(0xFFF7F8FA),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0E141B),
      surfaceContainerHighest: Color(0xFFEFF2F5),
      onSurfaceVariant: Color(0xFF4A5568),
      outline: Color(0xFFC9D2DB),
      outlineVariant: Color(0xFFE2E8EE),
      shadow: Color(0xFF0B0F14),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF1A222C),
      onInverseSurface: Color(0xFFEDF1F5),
      inversePrimary: Color(0xFF7BE8BC),
      surfaceTint: Color(0xFF0E9F6E),
    ),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF3B82F6),
    danger: Color(0xFFEF4444),
    brandGradient: [Color(0xFF0E9F6E), Color(0xFF22C55E), Color(0xFFF97316)],
    glassColor: Color(0xE6FFFFFF),
  );

  static const AppColors dark = AppColors._(
    scheme: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF34D399),
      onPrimary: Color(0xFF04271C),
      primaryContainer: Color(0xFF0B5C42),
      onPrimaryContainer: Color(0xFFB6F3D8),
      secondary: Color(0xFFFF9A62),
      onSecondary: Color(0xFF3A1503),
      secondaryContainer: Color(0xFF5C2A0E),
      onSecondaryContainer: Color(0xFFFFDCC9),
      tertiary: Color(0xFFA78BFA),
      onTertiary: Color(0xFF2A1B5E),
      tertiaryContainer: Color(0xFF453385),
      onTertiaryContainer: Color(0xFFE0DBFF),
      error: Color(0xFFFF6B70),
      onError: Color(0xFF450A0E),
      errorContainer: Color(0xFF6E1A1E),
      onErrorContainer: Color(0xFFFFD9DA),
      surfaceContainerLowest: Color(0xFF0B0F14),
      surface: Color(0xFF12161D),
      onSurface: Color(0xFFE7ECF1),
      surfaceContainerHighest: Color(0xFF1C232D),
      onSurfaceVariant: Color(0xFFA7B2BE),
      outline: Color(0xFF46505C),
      outlineVariant: Color(0xFF2A323D),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE7ECF1),
      onInverseSurface: Color(0xFF12161D),
      inversePrimary: Color(0xFF0E9F6E),
      surfaceTint: Color(0xFF34D399),
    ),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    info: Color(0xFF60A5FA),
    danger: Color(0xFFF87171),
    brandGradient: [Color(0xFF34D399), Color(0xFF6EE7B7), Color(0xFFFF9A62)],
    glassColor: Color(0x990F171F),
  );

  /// True-black palette for AMOLED displays. Surfaces are pure black so pixels
  /// turn off entirely, saving battery and maximising contrast.
  static const AppColors amoled = AppColors._(
    scheme: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF34D399),
      onPrimary: Color(0xFF04271C),
      primaryContainer: Color(0xFF0B5C42),
      onPrimaryContainer: Color(0xFFB6F3D8),
      secondary: Color(0xFFFF9A62),
      onSecondary: Color(0xFF3A1503),
      secondaryContainer: Color(0xFF5C2A0E),
      onSecondaryContainer: Color(0xFFFFDCC9),
      tertiary: Color(0xFFA78BFA),
      onTertiary: Color(0xFF2A1B5E),
      tertiaryContainer: Color(0xFF453385),
      onTertiaryContainer: Color(0xFFE0DBFF),
      error: Color(0xFFFF6B70),
      onError: Color(0xFF450A0E),
      errorContainer: Color(0xFF6E1A1E),
      onErrorContainer: Color(0xFFFFD9DA),
      surfaceContainerLowest: Color(0xFF000000),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFE7ECF1),
      surfaceContainerHighest: Color(0xFF0E110E),
      onSurfaceVariant: Color(0xFFA7B2BE),
      outline: Color(0xFF46505C),
      outlineVariant: Color(0xFF232A23),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE7ECF1),
      onInverseSurface: Color(0xFF0B0B0B),
      inversePrimary: Color(0xFF0E9F6E),
      surfaceTint: Color(0xFF34D399),
    ),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    info: Color(0xFF60A5FA),
    danger: Color(0xFFF87171),
    brandGradient: [Color(0xFF34D399), Color(0xFF6EE7B7), Color(0xFFFF9A62)],
    glassColor: Color(0x99000000),
  );
}
