import 'package:rational/rational.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/rounding_mode.dart';
import '../../valobj/credit_error_code.dart';
import '../../valobj/equal_installment_amount.dart';
import 'interest_accrual_policy.dart';

class InstallmentAmountAllocation {
  const InstallmentAmountAllocation({
    required this.principal,
    required this.interest,
    required this.fee,
  });

  final Money principal;
  final Money interest;
  final Money fee;
}

/// 一个阶段的本息分摊输入：期初本金、期末本金、每期期利率与舍入方式。
class RepaymentMethodCalculationInput {
  const RepaymentMethodCalculationInput({
    required this.openingPrincipal,
    required this.endPrincipal,
    required this.rates,
    required this.rounding,
    this.installmentAmount = const EqualInstallmentAmount.nominalRate(),
  });

  final Money openingPrincipal;
  final Money endPrincipal;
  final List<PeriodRate> rates;
  final RoundingMode rounding;
  final EqualInstallmentAmount installmentAmount;

  int get periodCount => rates.length;
}

class RepaymentMethodCalculation {
  const RepaymentMethodCalculation({
    required this.allocations,
    this.installmentAmount,
  });

  final List<InstallmentAmountAllocation> allocations;

  /// 等额本息实际采用的固定额；其他方式为空。
  final Money? installmentAmount;
}

/// 还款方式只决定各期本金的分摊形状；利率换算与手续费不在此处。
abstract interface class RepaymentMethodCalculator {
  RepaymentMethodCalculation calculate(RepaymentMethodCalculationInput input);
}

class EqualInstallmentCalculator implements RepaymentMethodCalculator {
  const EqualInstallmentCalculator();

  @override
  RepaymentMethodCalculation calculate(RepaymentMethodCalculationInput input) {
    final n = input.periodCount;
    final opening = input.openingPrincipal.minorUnits;
    final end = input.endPrincipal.minorUnits;
    final installmentMinor = switch (input.installmentAmount) {
      FixedInstallmentAmount(:final amount) => _requirePositive(amount),
      NominalRateInstallmentAmount() => _solveInstallment(
        openingMinor: opening,
        endMinor: end,
        rates: [for (final rate in input.rates) rate.nominal],
        rounding: input.rounding,
      ),
      ActualRateInstallmentAmount() => _solveInstallment(
        openingMinor: opening,
        endMinor: end,
        rates: [for (final rate in input.rates) rate.actual],
        rounding: input.rounding,
      ),
    };

    final allocations = <InstallmentAmountAllocation>[];
    var balance = opening;
    for (var i = 0; i < n; i++) {
      final interest = _interestFor(balance, input.rates[i], input.rounding);
      final int principal;
      if (i == n - 1) {
        principal = balance - end;
        if (principal < 0) {
          throw _invalid(
            'Installment amount repays the principal before the final period.',
          );
        }
      } else {
        principal = installmentMinor - interest;
        if (principal < 0) {
          throw _invalid(
            'Installment amount does not cover the interest of period ${i + 1}.',
          );
        }
      }
      allocations.add(_allocation(principal, interest));
      balance -= principal;
    }
    return RepaymentMethodCalculation(
      allocations: allocations,
      installmentAmount: Money(minorUnits: installmentMinor),
    );
  }

  int _requirePositive(Money amount) {
    if (amount.minorUnits <= 0) {
      throw _invalid('Fixed installment amount must be positive.');
    }
    return amount.minorUnits;
  }

  /// A = (p0·Π(1+r_i) − pn) / Σ_i Π_{j>i}(1+r_j)
  int _solveInstallment({
    required int openingMinor,
    required int endMinor,
    required List<Rational> rates,
    required RoundingMode rounding,
  }) {
    var paymentGrowth = Rational.zero;
    var suffix = Rational.one;
    for (var i = rates.length - 1; i >= 0; i--) {
      paymentGrowth += suffix;
      suffix *= Rational.one + rates[i];
    }
    final amount =
        (Rational.fromInt(openingMinor) * suffix - Rational.fromInt(endMinor)) /
        paymentGrowth;
    return amount.roundToInt(rounding);
  }
}

class EqualPrincipalCalculator implements RepaymentMethodCalculator {
  const EqualPrincipalCalculator();

  @override
  RepaymentMethodCalculation calculate(RepaymentMethodCalculationInput input) {
    final n = input.periodCount;
    final total =
        input.openingPrincipal.minorUnits - input.endPrincipal.minorUnits;
    final principals = splitEvenly(total, n, input.rounding);
    final allocations = <InstallmentAmountAllocation>[];
    var balance = input.openingPrincipal.minorUnits;
    for (var i = 0; i < n; i++) {
      final interest = _interestFor(balance, input.rates[i], input.rounding);
      allocations.add(_allocation(principals[i], interest));
      balance -= principals[i];
    }
    return RepaymentMethodCalculation(allocations: allocations);
  }
}

class InterestFirstCalculator implements RepaymentMethodCalculator {
  const InterestFirstCalculator();

  @override
  RepaymentMethodCalculation calculate(RepaymentMethodCalculationInput input) {
    final n = input.periodCount;
    final opening = input.openingPrincipal.minorUnits;
    return RepaymentMethodCalculation(
      allocations: [
        for (var i = 0; i < n; i++)
          _allocation(
            i == n - 1 ? opening - input.endPrincipal.minorUnits : 0,
            _interestFor(opening, input.rates[i], input.rounding),
          ),
      ],
    );
  }
}

class CustomInstallmentCalculator implements RepaymentMethodCalculator {
  const CustomInstallmentCalculator();

  @override
  RepaymentMethodCalculation calculate(RepaymentMethodCalculationInput input) {
    return RepaymentMethodCalculation(
      allocations: [
        for (var i = 0; i < input.periodCount; i++) _allocation(0, 0),
      ],
    );
  }
}

/// 把 [totalMinor] 均分为 [count] 份：每份按 [rounding] 落到分，尾差记入最后一份。
List<int> splitEvenly(int totalMinor, int count, RoundingMode rounding) {
  if (count <= 0) {
    throw ArgumentError.value(count, 'count', 'Must be > 0');
  }
  var share = Rational(
    BigInt.from(totalMinor),
    BigInt.from(count),
  ).roundToInt(rounding);
  var last = totalMinor - share * (count - 1);
  if (last < 0 || (totalMinor >= 0 && share < 0)) {
    share = totalMinor ~/ count;
    last = totalMinor - share * (count - 1);
  }
  return [for (var i = 0; i < count - 1; i++) share, last];
}

int _interestFor(int balanceMinor, PeriodRate rate, RoundingMode rounding) {
  return (Rational.fromInt(balanceMinor) * rate.actual).roundToInt(rounding);
}

InstallmentAmountAllocation _allocation(int principal, int interest) {
  return InstallmentAmountAllocation(
    principal: Money(minorUnits: principal),
    interest: Money(minorUnits: interest),
    fee: Money.zero(),
  );
}

BusinessException _invalid(String message) {
  return BusinessException(
    CreditErrorCode.contractInvalidCommand,
    message: message,
  );
}
