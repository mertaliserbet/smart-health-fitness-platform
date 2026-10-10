import 'package:flutter_test/flutter_test.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_form.dart';

void main() {
  group('name validation', () {
    for (final name in [
      'Mert Ali',
      'Şerbet',
      'Çağrı',
      'Özgür',
      'İrem',
      'Gökçe',
      'Jean-Luc',
      "O'Connor",
      'O’Connor',
      ' Mert  Ali ',
      'Jose\u0301',
      'I\u0307rem',
      'Αλέξανδρος',
      '李明',
      'محمد',
      'अनन्या',
      '𐐀𐐨',
      'A',
      'A' * 100,
    ]) {
      test('accepts $name', () => expect(AuthValidation.name(name), isNull));
    }

    for (final name in [
      '',
      '   ',
      '123',
      'Mert1',
      'Mert١',
      'Mert_Ali',
      'Mert@Ali',
      'Mert🙂',
      '-',
      "''",
      '-Mert',
      'Mert-',
      "'Mert",
      "Mert'",
      'Jean--Luc',
      "O''Connor",
      'Mert - Ali',
      '\u0301Mert',
      'Mert\tAli',
      'Mert\n',
      '\nMert',
      'A' * 101,
    ]) {
      test('rejects ${name.codeUnits}', () {
        expect(AuthValidation.name(name), isNotNull);
      });
    }
    test('rejects null', () => expect(AuthValidation.name(null), isNotNull));
  });
}
