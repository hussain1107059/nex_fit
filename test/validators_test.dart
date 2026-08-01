import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/utils/validators.dart';

void main() {
  group('Validators.validateEmail', () {
    test('accepts a valid email', () {
      expect(Validators.validateEmail('farhan@example.com'), isNull);
    });

    test('trims surrounding whitespace', () {
      expect(Validators.validateEmail('  farhan@example.com  '), isNull);
    });

    test('rejects an empty value', () {
      expect(Validators.validateEmail(''), isNotNull);
    });

    test('rejects an invalid email', () {
      expect(Validators.validateEmail('not-an-email'), isNotNull);
    });
  });

  group('Validators.validateRequired', () {
    test('accepts a non-blank value', () {
      expect(Validators.validateRequired('value'), isNull);
    });

    test('rejects blank values', () {
      expect(Validators.validateRequired(''), isNotNull);
      expect(Validators.validateRequired('   '), isNotNull);
      expect(Validators.validateRequired(null), isNotNull);
    });
  });

  group('Validators.validateName', () {
    test('accepts a normal name', () {
      expect(Validators.validateName('Rahim'), isNull);
    });

    test('rejects a blank name', () {
      expect(Validators.validateName(''), isNotNull);
    });

    test('rejects a name longer than the maximum length', () {
      expect(Validators.validateName('a' * 61), isNotNull);
      expect(Validators.validateName('a' * 60), isNull);
    });
  });

  group('Validators.validateConfirmPassword', () {
    test('passes when the passwords match', () {
      expect(Validators.validateConfirmPassword('secret', 'secret'), isNull);
    });

    test('rejects a mismatch', () {
      expect(Validators.validateConfirmPassword('secret', 'other'), isNotNull);
    });

    test('rejects an empty confirmation', () {
      expect(Validators.validateConfirmPassword('', 'secret'), isNotNull);
    });
  });

  group('Validators.validateStrongPassword', () {
    test('accepts a strong password', () {
      expect(Validators.validateStrongPassword('Abcd1234!'), isNull);
    });

    test('rejects a short password', () {
      expect(Validators.validateStrongPassword('Ab1!'), isNotNull);
    });

    test('rejects a password missing required character classes', () {
      expect(Validators.validateStrongPassword('abcdefgh'), isNotNull);
      expect(Validators.validateStrongPassword('ABCDEFGH'), isNotNull);
      expect(Validators.validateStrongPassword('ABCDabcd'), isNotNull);
      expect(Validators.validateStrongPassword('ABCDabcd1'), isNotNull);
    });

    test('rejects an empty password', () {
      expect(Validators.validateStrongPassword(''), isNotNull);
    });
  });
}
