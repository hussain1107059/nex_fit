import 'package:flutter/material.dart';

/// Typography scale for NexFit.
///
/// Uses the bundled [displayFamily] (Manrope) as the primary family with
/// [bengaliFamily] (Noto Sans Bengali) as an automatic fallback so Bangla
/// glyphs always render correctly.
class AppTypography {
  AppTypography._();

  static const String displayFamily = 'Manrope';
  static const String bengaliFamily = 'NotoSansBengali';
  static const List<String> familyFallback = [bengaliFamily];

  static TextTheme build(ColorScheme scheme) {
    const Color lightOnSurface = Color(0xFF0E141B);
    const Color lightOnSurfaceVariant = Color(0xFF4A5568);
    const Color darkOnSurface = Color(0xFFE7ECF1);
    const Color darkOnSurfaceVariant = Color(0xFFA7B2BE);

    final bool isDark = scheme.brightness == Brightness.dark;
    final Color onSurface = isDark ? darkOnSurface : lightOnSurface;
    final Color onSurfaceVariant =
        isDark ? darkOnSurfaceVariant : lightOnSurfaceVariant;

    const double letterSpacing = 0.2;

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -1,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.5,
        color: onSurface,
      ),
      displaySmall: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.25,
        color: onSurface,
      ),
      headlineLarge: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.25,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.3,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: letterSpacing,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: letterSpacing,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: letterSpacing,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.55,
        letterSpacing: letterSpacing,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.55,
        letterSpacing: letterSpacing,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: letterSpacing,
        color: onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.1,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.1,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: familyFallback,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.3,
        color: onSurfaceVariant,
      ),
    );
  }
}
