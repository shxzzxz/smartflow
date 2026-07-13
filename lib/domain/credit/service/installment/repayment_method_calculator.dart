import '../../../../core/money/money.dart';
import '../../valobj/installment_enums.dart';

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

class RepaymentMethodCalculationPeriod {
  const RepaymentMethodCalculationPeriod({
    required this.dayCount,
    required this.additionalOutstandingPrincipal,
  });

  final int dayCount;
  final Money additionalOutstandingPrincipal;
}

class RepaymentMethodCalculationInput {
  const RepaymentMethodCalculationInput({
    required this.principal,
    required this.periods,
    required this.accrualMethod,
    this.ratePeriod,
    this.ratePpm,
    this.remainingFeeMinor = 0,
    this.equalInstallmentOverrideMinor,
  });

  final Money principal;
  final List<RepaymentMethodCalculationPeriod> periods;
  final InterestAccrualMethod accrualMethod;
  final InterestRatePeriod? ratePeriod;
  final int? ratePpm;
  final int remainingFeeMinor;
  final int? equalInstallmentOverrideMinor;
}

abstract interface class RepaymentMethodCalculator {
  List<InstallmentAmountAllocation> calculate(
    RepaymentMethodCalculationInput input,
  );
}

class EqualInstallmentCalculator implements RepaymentMethodCalculator {
  const EqualInstallmentCalculator();

  @override
  List<InstallmentAmountAllocation> calculate(
    RepaymentMethodCalculationInput input,
  ) {
    final monthlyRate = _toMonthlyRate(input.ratePeriod, input.ratePpm);
    final n = input.periods.length;
    final int installmentMinor;
    final override = input.equalInstallmentOverrideMinor;
    if (override != null && override > 0) {
      installmentMinor = override;
    } else if (monthlyRate == 0) {
      return const EqualPrincipalCalculator().calculate(input);
    } else {
      installmentMinor = _solveInstallment(
        principalMinor: input.principal.minorUnits,
        monthlyRate: monthlyRate,
        accrual: input.accrualMethod,
        periods: input.periods,
      );
    }

    final allocations = <InstallmentAmountAllocation>[];
    var remaining = input.principal.minorUnits;
    var principalAccum = 0;
    for (var i = 0; i < n; i++) {
      final isLast = i == n - 1;
      final interestMinor = _interestForPeriod(
        balanceMinor:
            remaining +
            input.periods[i].additionalOutstandingPrincipal.minorUnits,
        monthlyRate: monthlyRate,
        days: input.periods[i].dayCount,
        accrual: input.accrualMethod,
      );
      var principalMinor = installmentMinor - interestMinor;
      if (isLast) {
        principalMinor = input.principal.minorUnits - principalAccum;
      }
      allocations.add(
        InstallmentAmountAllocation(
          principal: Money(minorUnits: principalMinor),
          interest: Money(minorUnits: interestMinor),
          fee: Money.zero(),
        ),
      );
      remaining -= principalMinor;
      principalAccum += principalMinor;
    }
    return allocations;
  }
}

class EqualPrincipalCalculator implements RepaymentMethodCalculator {
  const EqualPrincipalCalculator();

  @override
  List<InstallmentAmountAllocation> calculate(
    RepaymentMethodCalculationInput input,
  ) {
    final monthlyRate = _toMonthlyRate(input.ratePeriod, input.ratePpm);
    final n = input.periods.length;
    final perPrincipal = input.principal.minorUnits ~/ n;
    final allocations = <InstallmentAmountAllocation>[];
    var remaining = input.principal.minorUnits;
    var principalAccum = 0;
    for (var i = 0; i < n; i++) {
      var principalMinor = perPrincipal;
      if (i == n - 1) {
        principalMinor = input.principal.minorUnits - principalAccum;
      }
      final interestMinor = _interestForPeriod(
        balanceMinor:
            remaining +
            input.periods[i].additionalOutstandingPrincipal.minorUnits,
        monthlyRate: monthlyRate,
        days: input.periods[i].dayCount,
        accrual: input.accrualMethod,
      );
      allocations.add(
        InstallmentAmountAllocation(
          principal: Money(minorUnits: principalMinor),
          interest: Money(minorUnits: interestMinor),
          fee: Money.zero(),
        ),
      );
      remaining -= principalMinor;
      principalAccum += principalMinor;
    }
    return allocations;
  }
}

class InterestFirstCalculator implements RepaymentMethodCalculator {
  const InterestFirstCalculator();

  @override
  List<InstallmentAmountAllocation> calculate(
    RepaymentMethodCalculationInput input,
  ) {
    final monthlyRate = _toMonthlyRate(input.ratePeriod, input.ratePpm);
    final n = input.periods.length;
    return [
      for (var i = 0; i < n; i++)
        InstallmentAmountAllocation(
          principal: Money(
            minorUnits: i == n - 1 ? input.principal.minorUnits : 0,
          ),
          interest: Money(
            minorUnits: _interestForPeriod(
              balanceMinor:
                  input.principal.minorUnits +
                  input.periods[i].additionalOutstandingPrincipal.minorUnits,
              monthlyRate: monthlyRate,
              days: input.periods[i].dayCount,
              accrual: input.accrualMethod,
            ),
          ),
          fee: Money.zero(),
        ),
    ];
  }
}

class FlatFeeCalculator implements RepaymentMethodCalculator {
  const FlatFeeCalculator();

  @override
  List<InstallmentAmountAllocation> calculate(
    RepaymentMethodCalculationInput input,
  ) {
    final periods = input.periods.length;
    final perPrincipal = input.principal.minorUnits ~/ periods;
    final perFee = input.remainingFeeMinor ~/ periods;
    final allocations = <InstallmentAmountAllocation>[];
    var principalAccum = 0;
    var feeAccum = 0;
    for (var i = 0; i < periods; i++) {
      var principalMinor = perPrincipal;
      var feeMinor = perFee;
      if (i == periods - 1) {
        principalMinor = input.principal.minorUnits - principalAccum;
        feeMinor = input.remainingFeeMinor - feeAccum;
      }
      allocations.add(
        InstallmentAmountAllocation(
          principal: Money(minorUnits: principalMinor),
          interest: Money.zero(),
          fee: Money(minorUnits: feeMinor),
        ),
      );
      principalAccum += principalMinor;
      feeAccum += feeMinor;
    }
    return allocations;
  }
}

class CustomInstallmentCalculator implements RepaymentMethodCalculator {
  const CustomInstallmentCalculator();

  @override
  List<InstallmentAmountAllocation> calculate(
    RepaymentMethodCalculationInput input,
  ) {
    final zero = Money.zero();
    return [
      for (var i = 0; i < input.periods.length; i++)
        InstallmentAmountAllocation(principal: zero, interest: zero, fee: zero),
    ];
  }
}

int _interestForPeriod({
  required int balanceMinor,
  required double monthlyRate,
  required int days,
  required InterestAccrualMethod accrual,
}) {
  switch (accrual) {
    case InterestAccrualMethod.daily:
      return (balanceMinor * monthlyRate * days / 30).round();
    case InterestAccrualMethod.monthly:
      return (balanceMinor * monthlyRate).round();
  }
}

int _solveInstallment({
  required int principalMinor,
  required double monthlyRate,
  required InterestAccrualMethod accrual,
  required List<RepaymentMethodCalculationPeriod> periods,
}) {
  var additionalInterestGrowth = 0.0;
  var paymentGrowth = 0.0;
  var suffix = 1.0;
  for (var i = periods.length - 1; i >= 0; i--) {
    final period = periods[i];
    final periodRate = _periodRate(
      monthlyRate: monthlyRate,
      days: period.dayCount,
      accrual: accrual,
    );
    paymentGrowth += suffix;
    additionalInterestGrowth +=
        period.additionalOutstandingPrincipal.minorUnits * periodRate * suffix;
    suffix *= 1 + periodRate;
  }
  return ((principalMinor * suffix + additionalInterestGrowth) / paymentGrowth)
      .round();
}

double _periodRate({
  required double monthlyRate,
  required int days,
  required InterestAccrualMethod accrual,
}) {
  switch (accrual) {
    case InterestAccrualMethod.daily:
      return monthlyRate * days / 30;
    case InterestAccrualMethod.monthly:
      return monthlyRate;
  }
}

double _toMonthlyRate(InterestRatePeriod? period, int? ppm) {
  if (period == null || ppm == null || ppm == 0) {
    return 0;
  }
  final rate = ppm / 1000000.0;
  switch (period) {
    case InterestRatePeriod.annual:
      return rate / 12.0;
    case InterestRatePeriod.monthly:
      return rate;
    case InterestRatePeriod.daily:
      return rate * 30.0;
  }
}
