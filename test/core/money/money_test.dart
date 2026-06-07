import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';

void main() {
  group('Money', () {
    test('stores values in minor units', () {
      final money = Money.parse('12.34');

      expect(money.minorUnits, 1234);
      expect(money.major.toString(), '12.34');
    });

    test('supports arithmetic', () {
      final first = Money.parse('10.00');
      final second = Money.parse('2.35');

      expect((first + second).format(), '12.35');
      expect((first - second).format(), '7.65');
      expect((-second).format(), '-2.35');
    });

    test('rejects values smaller than cent precision', () {
      expect(() => Money.parse('1.234'), throwsFormatException);
    });

    test('tryParse returns null for invalid input', () {
      expect(Money.tryParse('12.34'), const Money(minorUnits: 1234));
      expect(Money.tryParse(null), isNull);
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('1.234'), isNull);
      expect(Money.tryParse('abc'), isNull);
    });

    test('compares by minor units', () {
      final first = Money.parse('1.00');
      final second = Money.parse('2.00');

      expect(first.compareTo(second), lessThan(0));
    });
  });
}
