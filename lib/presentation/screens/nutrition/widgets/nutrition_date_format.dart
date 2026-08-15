import '../../../../core/extensions/string_extensions.dart';
import '../../../../l10n/app_localizations.dart';

/// Formats a date as "12 Aug" (day in Bangla digits, localized month
/// abbreviation) plus the year when it differs from the current year.
String formatNutritionDate(DateTime date, AppLocalizations l10n) {
  final DateTime now = DateTime.now();
  final String month = switch (date.month) {
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
  return '${date.day.toString().toBanglaDigits()} $month'
      '${date.year != now.year ? ' ${date.year.toString().toBanglaDigits()}' : ''}';
}