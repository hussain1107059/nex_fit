import '../../../../core/extensions/string_extensions.dart';

/// Formats a date as "12 Aug" (day in Bangla digits, English month
/// abbreviation) plus the year when it differs from the current year.
String formatNutritionDate(DateTime date) {
  final DateTime now = DateTime.now();
  final String month = switch (date.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  return '${date.day.toString().toBanglaDigits()} $month'
      '${date.year != now.year ? ' ${date.year.toString().toBanglaDigits()}' : ''}';
}
