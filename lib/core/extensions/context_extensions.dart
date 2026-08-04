import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

extension ContextExtensions on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  bool get isWide => MediaQuery.sizeOf(this).width >= 600;

  Future<void> dismissKeyboard() async {
    final FocusScopeNode currentFocus = FocusScope.of(this);
    if (!currentFocus.hasPrimaryFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }
}
