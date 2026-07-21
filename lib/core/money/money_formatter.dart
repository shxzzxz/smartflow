import 'money.dart';

enum MoneyFormatStyle { exact, compact }

const _minorUnitsPerTenThousand = 10000 * 100;
const _minorUnitsPerHundredMillion = 100000000 * 100;

String formatMoney(
  Money money, {
  MoneyFormatStyle style = MoneyFormatStyle.exact,
}) {
  return switch (style) {
    MoneyFormatStyle.exact => money.format(),
    MoneyFormatStyle.compact => _formatCompactMoney(money),
  };
}

String _formatCompactMoney(Money money) {
  final absoluteMinorUnits = money.minorUnits.abs();
  final sign = money.minorUnits < 0 ? '-' : '';

  if (absoluteMinorUnits >= _minorUnitsPerHundredMillion) {
    return '$sign${_formatScaled(absoluteMinorUnits, _minorUnitsPerHundredMillion)}亿';
  }
  if (absoluteMinorUnits >= _minorUnitsPerTenThousand) {
    return '$sign${_formatScaled(absoluteMinorUnits, _minorUnitsPerTenThousand)}W';
  }

  return _trimTrailingZeros(money.format());
}

String _formatScaled(int minorUnits, int unitMinorUnits) {
  final roundedHundredths =
      (minorUnits * 100 + unitMinorUnits ~/ 2) ~/ unitMinorUnits;
  final whole = roundedHundredths ~/ 100;
  final fraction = roundedHundredths % 100;
  if (fraction == 0) return '$whole';
  if (fraction % 10 == 0) return '$whole.${fraction ~/ 10}';
  return '$whole.${fraction.toString().padLeft(2, '0')}';
}

String _trimTrailingZeros(String value) {
  return value.replaceFirst(RegExp(r'\.0+$|(?<=\.[0-9])0$'), '');
}
