class AppConstants {
  AppConstants._();

  static const String appName = 'NexFit';
  static const String appTagline = 'Start your fitness journey today';

  static const String databaseName = 'nexfit.db';
  static const int databaseVersion = 6;

  static const Duration splashDuration = Duration(milliseconds: 1800);
  static const Duration debounceDuration = Duration(milliseconds: 400);
  static const Duration animationDuration = Duration(milliseconds: 280);

  static const int maxNameLength = 60;
  static const int maxPasswordLength = 64;
  static const int minPasswordLength = 6;
  static const int strongPasswordLength = 8;

  static const String defaultLocale = 'bn';
  static const String fallbackLocale = 'en';

  static const double desktopBreakpoint = 900;
  static const double tabletBreakpoint = 600;
}
