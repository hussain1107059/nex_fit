import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

extension ContextExtensions on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  MediaQueryData get mediaQuery => MediaQuery.of(this);

  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  bool get isWide => screenWidth >= 600;

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  Future<void> dismissKeyboard() async {
    final FocusScopeNode currentFocus = FocusScope.of(this);
    if (!currentFocus.hasPrimaryFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }
}
