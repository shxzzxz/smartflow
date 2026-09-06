import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';
import 'package:smartflow/core/money/rounding_mode.dart';

Rational _r(int numerator, int denominator) {
  return Rational(BigInt.from(numerator), BigInt.from(denominator));
}

void main() {
  test('halfUp rounds halves away from zero', () {
    expect(_r(5, 2).roundToInt(RoundingMode.halfUp), 3);
    expect(_r(-5, 2).roundToInt(RoundingMode.halfUp), -3);
    expect(_r(24, 10).roundToInt(RoundingMode.halfUp), 2);
    expect(_r(26, 10).roundToInt(RoundingMode.halfUp), 3);
  });

  test('halfEven rounds halves to the even neighbour', () {
    expect(_r(5, 2).roundToInt(RoundingMode.halfEven), 2);
    expect(_r(7, 2).roundToInt(RoundingMode.halfEven), 4);
    expect(_r(-5, 2).roundToInt(RoundingMode.halfEven), -2);
    expect(_r(26, 10).roundToInt(RoundingMode.halfEven), 3);
    expect(_r(24, 10).roundToInt(RoundingMode.halfEven), 2);
  });

  test('down truncates toward zero', () {
    expect(_r(29, 10).roundToInt(RoundingMode.down), 2);
    expect(_r(-29, 10).roundToInt(RoundingMode.down), -2);
  });

  test('up rounds away from zero', () {
    expect(_r(21, 10).roundToInt(RoundingMode.up), 3);
    expect(_r(-21, 10).roundToInt(RoundingMode.up), -3);
    expect(_r(3, 1).roundToInt(RoundingMode.up), 3);
  });
}
