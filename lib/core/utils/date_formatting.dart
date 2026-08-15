import '../../l10n/app_localizations.dart';
import '../extensions/string_extensions.dart';

/// Localized month abbreviation (uses the shared `month*` l10n keys so the
/// charts render Bangla month names in the Bangla locale).
String localizedMonth(AppLocalizations l10n, int month) {
  return switch (month) {
    1 => l10n.monthJan,
    2 => l10n.monthFeb,
    3 => l10n.monthMar,
    4 => l10n.monthApr,
    5 => l10n.monthMay,
    6 => l10n.monthJun,
    7 => l10n.monthJul,
    8 => l10n.monthAug,
    9 => l10n.monthSep,
    10 => l10n.monthOct,
    11 => l10n.monthNov,
    _ => l10n.monthDec,
  };
}

/// Formats a date as `12 Aug 2026` (Bangla digits, localized month).
String formatLocalizedDate(DateTime date, AppLocalizations l10n) {
  return '${date.day.toString().toBanglaDigits()} '
      '${localizedMonth(l10n, date.month)} '
      '${date.year.toString().toBanglaDigits()}';
}