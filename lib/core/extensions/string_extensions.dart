import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Tracks the active app language so number strings can pick the right digit
/// set. Kept in sync by `LocaleNotifier`.
class DigitLocale {
  DigitLocale._();

  static String currentLanguageCode = AppConstants.defaultLocale;
}

extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  /// Renders ASCII digits as Bangla numerals when the active language is
  /// Bangla; otherwise returns the string unchanged. Pass [asBangla] to
  /// override the decision when a concrete localized instance is available.
  String toBanglaDigits({bool? asBangla}) {
    final bool useBangla =
        asBangla ?? DigitLocale.currentLanguageCode == 'bs' ||
        DigitLocale.currentLanguageCode == 'bn';
    if (!useBangla) return this;
    const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return codeUnits.map((unit) {
      if (unit >= 0x30 && unit <= 0x39) return bangla[unit - 0x30];
      return String.fromCharCode(unit);
    }).join();
  }
}

extension SizedBoxExtensions on num {
  SizedBox get widthSpace => SizedBox(width: toDouble());

  SizedBox get heightSpace => SizedBox(height: toDouble());
}
