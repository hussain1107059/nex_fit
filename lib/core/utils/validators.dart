/// Input validators used by form fields across the app.
class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );

  static String? validateEmail(String? value, {String? requiredError, String? invalidError}) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return requiredError ?? 'This field is required';
    if (!_emailRegExp.hasMatch(text)) return invalidError ?? 'Enter a valid email address';
    return null;
  }

  static String? validateRequired(String? value, {String? requiredError}) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return requiredError ?? 'This field is required';
    return null;
  }

  static String? validateName(String? value, {String? requiredError, int maxLength = 60}) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return requiredError ?? 'This field is required';
    if (text.length > maxLength) return 'Value is too long';
    return null;
  }

  static String? validateConfirmPassword(String? value, String? password, {
    String? requiredError,
    String? mismatchError,
  }) {
    final String text = value ?? '';
    if (text.isEmpty) return requiredError ?? 'This field is required';
    if (text != password) return mismatchError ?? 'Passwords do not match';
    return null;
  }

  /// Validates a password without strength requirements: required plus a
  /// minimum length only. Used by registration so weak passwords are accepted.
  static String? validatePassword(String? value, {
    String? requiredError,
    String? tooShortError,
    int minLength = 6,
  }) {
    final String text = value ?? '';
    if (text.isEmpty) return requiredError ?? 'This field is required';
    if (text.length < minLength) {
      return tooShortError ?? 'Password must be at least $minLength characters';
    }
    return null;
  }

  /// Validates a strong password: minimum length plus at least one
  /// uppercase letter, one lowercase letter, one digit and one symbol.
  static String? validateStrongPassword(String? value, {
    String? requiredError,
    String? tooShortError,
    String? weakError,
    int minLength = 8,
  }) {
    final String text = value ?? '';
    if (text.isEmpty) return requiredError ?? 'This field is required';
    if (text.length < minLength) {
      return tooShortError ?? 'Password must be at least 8 characters';
    }
    final bool hasUpper = text.contains(RegExp(r'[A-Z]'));
    final bool hasLower = text.contains(RegExp(r'[a-z]'));
    final bool hasDigit = text.contains(RegExp(r'[0-9]'));
    final bool hasSpecial = text.contains(RegExp(r'[^A-Za-z0-9]'));
    if (!(hasUpper && hasLower && hasDigit && hasSpecial)) {
      return weakError ?? 'Use a stronger password';
    }
    return null;
  }
}
