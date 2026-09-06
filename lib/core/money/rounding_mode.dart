import 'package:rational/rational.dart';

/// 精确金额落到最小单位（分）时的取整方式。
enum RoundingMode {
  /// 四舍五入：恰好一半时远离零。
  halfUp,

  /// 银行家舍入：恰好一半时取偶数。
  halfEven,

  /// 舍去：向零截断。
  down,

  /// 进一：远离零。
  up,
}

extension RationalRounding on Rational {
  /// 按 [mode] 取整到整数。调用方保证数值已以分为单位。
  int roundToInt(RoundingMode mode) {
    return switch (mode) {
      RoundingMode.halfUp => round().toInt(),
      RoundingMode.halfEven => _roundHalfEven().toInt(),
      RoundingMode.down => truncate().toInt(),
      RoundingMode.up => (signum < 0 ? floor() : ceil()).toInt(),
    };
  }

  BigInt _roundHalfEven() {
    final lower = floor();
    final comparison = (this - Rational(lower)).compareTo(_half);
    if (comparison < 0) return lower;
    if (comparison > 0) return lower + BigInt.one;
    return lower.isEven ? lower : lower + BigInt.one;
  }
}

final Rational _half = Rational(BigInt.one, BigInt.two);
