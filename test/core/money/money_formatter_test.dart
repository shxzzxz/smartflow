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

    test('preserves value while trimming insignificant decimal zeros', () {
      expect(
        formatMoney(
          const Money(minorUnits: 5200000),
          style: MoneyFormatStyle.plain,
        ),
        '52000',
      );
      expect(
        formatMoney(
          const Money(minorUnits: -362099),
          style: MoneyFormatStyle.plain,
        ),
        '-3620.99',
      );
    });

    test('uses compact ten-thousand notation and trims trailing zeros', () {
      expect(
        formatMoney(
          const Money(minorUnits: -12400 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '-1.24万',
      );
      expect(
        formatMoney(
          const Money(minorUnits: 12000 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '1.2万',
      );
      expect(
        formatMoney(
          const Money(minorUnits: 10000 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '1万',
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

    test('keeps up to four integer digits and two decimal places', () {
      expect(
        formatMoney(
          const Money(minorUnits: 2500000 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '250万',
      );
      expect(
        formatMoney(
          const Money(minorUnits: 12345678 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '1234.57万',
      );
      expect(
        formatMoney(
          const Money(minorUnits: 99999999 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '1亿',
      );
      expect(
        formatMoney(
          const Money(minorUnits: 999999999999 * 100),
          style: MoneyFormatStyle.compact,
        ),
        '1万亿',
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
