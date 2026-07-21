import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/money_formatter.dart';

void main() {
  group('formatMoney', () {
    test('preserves exact cent precision when requested', () {
      expect(
        formatMoney(
          const Money(minorUnits: -123450),
          style: MoneyFormatStyle.exact,
        ),
        '-1234.50',
      );
    });

    test('uses compact ten-thousand notation and trims trailing zeros', () {
      expect(
        formatMoney(
          const Money(minorUnits: -12400 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '-1.24W',
      );
      expect(
        formatMoney(
          const Money(minorUnits: 12000 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '1.2W',
      );
      expect(
        formatMoney(
          const Money(minorUnits: 10000 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '1W',
      );
    });

    test('uses compact hundred-million notation', () {
      expect(
        formatMoney(
          const Money(minorUnits: 124000000 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '1.24亿',
      );
    });

    test('keeps ordinary compact amounts exact without trailing zeros', () {
      expect(
        formatMoney(
          const Money(minorUnits: -123450),
          style: MoneyFormatStyle.compact,
        ),
        '-1234.5',
      );
    });
  });
}
