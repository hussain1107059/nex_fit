import 'package:flutter/widgets.dart';

/// Spacing scale used across the app for consistent rhythm.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double xxxxl = 56;

  static const EdgeInsets page = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  static const EdgeInsets screen = EdgeInsets.all(md);
}
