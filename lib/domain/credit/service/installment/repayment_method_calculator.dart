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

class RepaymentMethodCalculationInput {
  const RepaymentMethodCalculationInput({
    required this.principal,
    required this.dayCounts,
    required this.accrualMethod,
    this.ratePeriod,
    this.ratePpm,
    this.remainingFeeMinor = 0,
    this.equalInstallmentOverrideMinor,
  });

  final Money principal;
  final List<int> dayCounts;
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
    final n = input.dayCounts.length;
    final int installmentMinor;
    final override = input.equalInstallmentOverrideMinor;
    if (override != null && override > 0) {
      installmentMinor = override;
    } else if (monthlyRate == 0) {
      return const EqualPrincipalCalculator().calculate(input);
    } else {
      switch (input.accrualMethod) {
        case InterestAccrualMethod.monthly:
          final p = input.principal.minorUnits.toDouble();
          final r = monthlyRate;
          final pow = _pow(1 + r, n);
          installmentMinor = (p * r * pow / (pow - 1)).round();
        case InterestAccrualMethod.daily:
          installmentMinor = _solveDailyInstallment(
            principalMinor: input.principal.minorUnits,
            monthlyRate: monthlyRate,
            dayCounts: input.dayCounts,
          );
      }
    }

    final allocations = <InstallmentAmountAllocation>[];
    var remaining = input.principal.minorUnits;
    var principalAccum = 0;
    for (var i = 0; i < n; i++) {
      final isLast = i == n - 1;
      final interestMinor = _interestForPeriod(
        balanceMinor: remaining,
        monthlyRate: monthlyRate,
        days: input.dayCounts[i],
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
    final n = input.dayCounts.length;
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
        balanceMinor: remaining,
        monthlyRate: monthlyRate,
        days: input.dayCounts[i],
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
    final n = input.dayCounts.length;
    return [
      for (var i = 0; i < n; i++)
        InstallmentAmountAllocation(
          principal: Money(
            minorUnits: i == n - 1 ? input.principal.minorUnits : 0,
          ),
          interest: Money(
            minorUnits: _interestForPeriod(
              balanceMinor: input.principal.minorUnits,
              monthlyRate: monthlyRate,
              days: input.dayCounts[i],
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
    final periods = input.dayCounts.length;
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
      for (var i = 0; i < input.dayCounts.length; i++)
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

int _solveDailyInstallment({
  required int principalMinor,
  required double monthlyRate,
  required List<int> dayCounts,
}) {
  final d = monthlyRate / 30;
  var prodAll = 1.0;
  for (final days in dayCounts) {
    prodAll *= (1 + d * days);
  }
  var sumOfProducts = 0.0;
  var suffix = 1.0;
  for (var i = dayCounts.length - 1; i >= 0; i--) {
    sumOfProducts += suffix;
    suffix *= (1 + d * dayCounts[i]);
  }
  return (principalMinor * prodAll / sumOfProducts).round();
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

double _pow(double base, int exp) {
  var result = 1.0;
  for (var i = 0; i < exp; i++) {
    result *= base;
  }
  return result;
}
