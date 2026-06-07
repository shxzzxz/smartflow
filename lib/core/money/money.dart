import 'package:decimal/decimal.dart';

class Money implements Comparable<Money> {
  const Money({required this.minorUnits});

  factory Money.zero() {
    return const Money(minorUnits: 0);
  }

  factory Money.fromMajor(Decimal amount) {
    final minor = amount.shift(2);
    if (!minor.isInteger) {
      throw FormatException('Money only supports cent precision: $amount');
    }

    return Money(minorUnits: minor.toBigInt().toInt());
  }

  factory Money.parse(String amount) {
    return Money.fromMajor(Decimal.parse(amount.trim()));
  }

  static Money? tryParse(String? amount) {
    if (amount == null) return null;
    try {
      return Money.parse(amount);
    } on FormatException {
      return null;
    }
  }

  final int minorUnits;

  Decimal get major => Decimal.fromInt(minorUnits).shift(-2);

  Money operator +(Money other) {
    return Money(minorUnits: minorUnits + other.minorUnits);
  }

  Money operator -(Money other) {
    return Money(minorUnits: minorUnits - other.minorUnits);
  }

  Money operator -() {
    return Money(minorUnits: -minorUnits);
  }

  Money abs() {
    return Money(minorUnits: minorUnits.abs());
  }

  String format() {
    return major.toStringAsFixed(2);
  }

  @override
  int compareTo(Money other) {
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) {
    return other is Money && other.minorUnits == minorUnits;
  }

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => format();
}
