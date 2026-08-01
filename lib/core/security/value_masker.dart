/// Masks sensitive values before they reach logs, diagnostics or the UI.
///
/// The goal is to keep the shape of a value (length, first letter) while
/// removing anything that could identify the user (full email, name, notes).
class ValueMasker {
  ValueMasker._();

  static const String _mask = '••••';

  /// Masks an email to `f••••@example.com` (domain kept, local-part masked).
  static String maskEmail(String? email) {
    if (email == null || email.isEmpty) return '';
    final int at = email.indexOf('@');
    if (at <= 0) return _mask;
    final String local = email.substring(0, at);
    final String domain = email.substring(at);
    final String head = local.isEmpty ? '' : local.substring(0, 1);
    return '$head$_mask$domain';
  }

  /// Masks a name to its first character followed by dots.
  static String maskName(String? name) {
    if (name == null || name.isEmpty) return '';
    return '${name.substring(0, 1)}$_mask';
  }

  /// Masks a free-text note to a fixed-length ellipsis.
  static String maskText(String? value) {
    if (value == null || value.isEmpty) return '';
    return _mask;
  }

  /// Masks a numeric weight/measurement to its integer part only.
  static String maskNumber(num? value) {
    if (value == null) return '';
    return '${value.toStringAsFixed(0)}$_mask';
  }

  /// Best-effort generic masker used by the error logger for unknown fields.
  static String mask(Object? value) {
    if (value == null) return '';
    return maskText(value.toString());
  }
}
