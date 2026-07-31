import 'package:flutter/material.dart';

/// Soft, premium shadow presets.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get brand => [
        BoxShadow(
          color: const Color(0xFF0E9F6E).withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}
