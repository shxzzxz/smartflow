import 'package:rational/rational.dart';

import 'installment_enums.dart';

/// 输入口径的利率：ppm（百万分之一）数值加上利率单位。
///
/// 它只表达"用户填的是什么"，不表达每期怎么计息；期利率换算由计息策略完成。
class InterestRate {
  const InterestRate({required this.ppm, required this.period});

  /// 利率单位与数值成对给出时才构成利率；任一为空视为免息。
  static InterestRate? maybe(InterestRatePeriod? period, int? ppm) {
    if (period == null || ppm == null) return null;
    return InterestRate(ppm: ppm, period: period);
  }

  final int ppm;
  final InterestRatePeriod period;

  Rational get fraction => Rational(BigInt.from(ppm), _ppmScale);

  bool get isZero => ppm == 0;

  @override
  bool operator ==(Object other) {
    return other is InterestRate && other.ppm == ppm && other.period == period;
  }

  @override
  int get hashCode => Object.hash(ppm, period);

  @override
  String toString() => 'InterestRate($ppm ppm / ${period.name})';
}

final BigInt _ppmScale = BigInt.from(1000000);
