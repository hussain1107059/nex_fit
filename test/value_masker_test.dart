import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/security/value_masker.dart';

void main() {
  group('ValueMasker', () {
    test('masks an email keeping the domain', () {
      expect(ValueMasker.maskEmail('farhan@example.com'), 'f••••@example.com');
      expect(ValueMasker.maskEmail(null), '');
    });

    test('masks a name to its first character', () {
      expect(ValueMasker.maskName('Rahim'), 'R••••');
      expect(ValueMasker.maskName(null), '');
    });

    test('masks free text to a fixed ellipsis', () {
      expect(ValueMasker.maskText('any sensitive text'), '••••');
      expect(ValueMasker.maskText(null), '');
      expect(ValueMasker.maskText(''), '');
    });

    test('masks a number keeping only the integer part', () {
      expect(ValueMasker.maskNumber(72.45), '72••••');
      expect(ValueMasker.maskNumber(null), '');
    });

    test('generic mask handles unknown values', () {
      expect(ValueMasker.mask('whatever'), '••••');
      expect(ValueMasker.mask(null), '');
    });

    test('masks emails inside text but keeps the rest readable', () {
      expect(
        ValueMasker.maskEmailInText(
          'postgrest_23505_duplicate key user farhan@example.com',
        ),
        'postgrest_23505_duplicate key user f••••@example.com',
      );
      expect(ValueMasker.maskEmailInText('plain message'), 'plain message');
      expect(ValueMasker.maskEmailInText(null), '');
      expect(ValueMasker.maskEmailInText(''), '');
    });
  });
}
