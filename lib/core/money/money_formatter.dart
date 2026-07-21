import 'money.dart';

enum MoneyFormatStyle { exact, plain, compact }

const _minorUnitsPerTenThousand = 10000 * 100;
const _minorUnitsPerHundredMillion = 100000000 * 100;
const _minorUnitsPerTrillion = 1000000000000 * 100;

String formatMoney(
  Money money, {
  MoneyFormatStyle style = MoneyFormatStyle.exact,
}) {
  return switch (style) {
    MoneyFormatStyle.exact => money.format(),
    MoneyFormatStyle.plain => _trimTrailingZeros(money.format()),
    MoneyFormatStyle.compact => _formatCompactMoney(money),
  };
}

String _formatCompactMoney(Money money) {
  final absoluteMinorUnits = money.minorUnits.abs();
  final sign = money.minorUnits < 0 ? '-' : '';

  if (absoluteMinorUnits >= _minorUnitsPerTrillion) {
    return '$sign${_formatScaled(absoluteMinorUnits, _minorUnitsPerTrillion)}万亿';
  }
  if (absoluteMinorUnits >= _minorUnitsPerHundredMillion) {
    final scaled = _roundedHundredths(
      absoluteMinorUnits,
      _minorUnitsPerHundredMillion,
    );
    if (scaled >= 10000 * 100) {
      return '$sign${_formatScaled(absoluteMinorUnits, _minorUnitsPerTrillion)}万亿';
    }
    return '$sign${_formatRoundedHundredths(scaled)}亿';
  }
  if (absoluteMinorUnits >= _minorUnitsPerTenThousand) {
    final scaled = _roundedHundredths(
      absoluteMinorUnits,
      _minorUnitsPerTenThousand,
    );
    if (scaled >= 10000 * 100) {
      return '$sign${_formatScaled(absoluteMinorUnits, _minorUnitsPerHundredMillion)}亿';
    }
    return '$sign${_formatRoundedHundredths(scaled)}万';
  }

  return _trimTrailingZeros(money.format());
}

String _formatScaled(int minorUnits, int unitMinorUnits) {
  return _formatRoundedHundredths(
    _roundedHundredths(minorUnits, unitMinorUnits),
  );
}

int _roundedHundredths(int minorUnits, int unitMinorUnits) {
  return (minorUnits * 100 + unitMinorUnits ~/ 2) ~/ unitMinorUnits;
}

String _formatRoundedHundredths(int roundedHundredths) {
  final whole = roundedHundredths ~/ 100;
  final fraction = roundedHundredths % 100;
  if (fraction == 0) return '$whole';
  if (fraction % 10 == 0) return '$whole.${fraction ~/ 10}';
  return '$whole.${fraction.toString().padLeft(2, '0')}';
}

String _trimTrailingZeros(String value) {
  return value.replaceFirst(RegExp(r'\.0+$|(?<=\.[0-9])0$'), '');
}
