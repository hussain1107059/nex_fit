import 'package:flutter/foundation.dart';

class AppAssets {
  AppAssets._();

  static const String logo = 'assets/icons/ic_logo.svg';
  static const String homeIcon = 'assets/icons/ic_home.svg';
  static const String workoutIcon = 'assets/icons/ic_workout.svg';
  static const String dietIcon = 'assets/icons/ic_diet.svg';
  static const String profileIcon = 'assets/icons/ic_profile.svg';
  static const String closeIcon = 'assets/icons/ic_close.svg';
  static const String linkIcon = 'assets/icons/ic_link.svg';

  static String get appLogo => kIsWeb ? logo : logo;
}
