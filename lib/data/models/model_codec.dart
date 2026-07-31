/// Shared conversions between Dart values and SQLite storage types.
/// Keeps the per-table mappers free of repeated timestamp/boolean logic.
class ModelCodec {
  ModelCodec._();

  /// Epoch milliseconds for a [DateTime], or null.
  static int? epochMs(DateTime? value) => value?.millisecondsSinceEpoch;

  /// A [DateTime] from epoch milliseconds, or null.
  static DateTime? fromEpochMs(int? value) {
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  static int boolToInt(bool value) => value ? 1 : 0;

  static bool intToBool(Object? value) => value == 1;

  /// A double from an int/num SQLite value, or null.
  static double? toDouble(Object? value) {
    if (value is int) return value.toDouble();
    return (value as num?)?.toDouble();
  }

  /// An int from any SQLite numeric value.
  static int toInt(Object? value) => (value as num?)?.toInt() ?? 0;
}
