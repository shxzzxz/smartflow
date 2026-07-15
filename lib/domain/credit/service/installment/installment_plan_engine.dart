import '../../../../core/money/money.dart';
import '../../valobj/installment_enums.dart';
import 'repayment_dates_strategy.dart';
import 'repayment_method_calculator.dart';

class InstallmentPlanConfig {
  const InstallmentPlanConfig({
    required this.remainingPrincipal,
    required this.firstPeriodNo,
    required this.accrualStartDate,
    required this.repaymentDates,
    required this.repaymentMethod,
    required this.interestAccrualMethod,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.remainingFeeMinor = 0,
    this.equalInstallmentOverrideMinor,
  }) : accrualPeriods = null;

  const InstallmentPlanConfig.withAccrualPeriods({
    required this.remainingPrincipal,
    required this.firstPeriodNo,
    required this.accrualPeriods,
    required this.repaymentMethod,
    required this.interestAccrualMethod,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.remainingFeeMinor = 0,
    this.equalInstallmentOverrideMinor,
  }) : accrualStartDate = null,
       repaymentDates = null;

  final Money remainingPrincipal;
  final int firstPeriodNo;
  final DateTime? accrualStartDate;
  final RepaymentDatesStrategy? repaymentDates;
  final InstallmentRepaymentMethod repaymentMethod;
  final InterestAccrualMethod interestAccrualMethod;
  final List<InstallmentAccrualPeriod>? accrualPeriods;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final int remainingFeeMinor;
  final int? equalInstallmentOverrideMinor;
}

class InstallmentAccrualPeriod {
  const InstallmentAccrualPeriod({
    required this.accrualStartDate,
    required this.repaymentDate,
    this.additionalOutstandingPrincipal = const Money(minorUnits: 0),
  });

  final DateTime accrualStartDate;
  final DateTime repaymentDate;
  final Money additionalOutstandingPrincipal;
}

class InstallmentSchedulePlanEntry {
  const InstallmentSchedulePlanEntry({
    required this.periodNo,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
  });

  final int periodNo;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
}

class InstallmentPlanEngine {
  const InstallmentPlanEngine({
    Map<InstallmentRepaymentMethod, RepaymentMethodCalculator>? calculators,
  }) : _calculators = calculators ?? _defaultCalculators;

  static const _defaultCalculators = {
    InstallmentRepaymentMethod.equalInstallment: EqualInstallmentCalculator(),
    InstallmentRepaymentMethod.equalPrincipal: EqualPrincipalCalculator(),
    InstallmentRepaymentMethod.interestFirst: InterestFirstCalculator(),
    InstallmentRepaymentMethod.flatFee: FlatFeeCalculator(),
    InstallmentRepaymentMethod.custom: CustomInstallmentCalculator(),
  };

  final Map<InstallmentRepaymentMethod, RepaymentMethodCalculator> _calculators;

  List<DateTime> generateDates({
    required DateTime firstRepaymentDate,
    required DateTime lastRepaymentDate,
    required int totalPeriods,
  }) {
    return IntervalRepaymentDates(
      firstDate: firstRepaymentDate,
      count: totalPeriods,
      lastDate: lastRepaymentDate,
    ).getDates();
  }

  List<InstallmentAmountAllocation> allocate({
    required Money remainingPrincipal,
    required DateTime anchorDate,
    required List<DateTime> pendingDates,
    required InstallmentRepaymentMethod method,
    required InterestAccrualMethod accrualMethod,
    InterestRatePeriod? ratePeriod,
    int? ratePpm,
    int remainingFeeMinor = 0,
    int? equalInstallmentOverrideMinor,
  }) {
    return plan(
          InstallmentPlanConfig(
            remainingPrincipal: remainingPrincipal,
            firstPeriodNo: 1,
            accrualStartDate: anchorDate,
            repaymentDates: ExplicitRepaymentDates(pendingDates),
            repaymentMethod: method,
            interestAccrualMethod: accrualMethod,
            interestRatePeriod: ratePeriod,
            interestRatePpm: ratePpm,
            remainingFeeMinor: remainingFeeMinor,
            equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
          ),
        )
        .map(
          (entry) => InstallmentAmountAllocation(
            principal: entry.expectedPrincipal,
            interest: entry.expectedInterest,
            fee: entry.expectedFee,
          ),
        )
        .toList();
  }

  List<InstallmentSchedulePlanEntry> generate({
    required Money principal,
    required DateTime borrowingDate,
    required DateTime firstRepaymentDate,
    required DateTime lastRepaymentDate,
    required int totalPeriods,
    required InstallmentRepaymentMethod method,
    required InterestAccrualMethod accrualMethod,
    InterestRatePeriod? ratePeriod,
    int? ratePpm,
    int totalFeeMinor = 0,
    int? equalInstallmentOverrideMinor,
  }) {
    return plan(
      InstallmentPlanConfig(
        remainingPrincipal: principal,
        firstPeriodNo: 1,
        accrualStartDate: borrowingDate,
        repaymentDates: IntervalRepaymentDates(
          firstDate: firstRepaymentDate,
          count: totalPeriods,
          lastDate: lastRepaymentDate,
        ),
        repaymentMethod: method,
        interestAccrualMethod: accrualMethod,
        interestRatePeriod: ratePeriod,
        interestRatePpm: ratePpm,
        remainingFeeMinor: totalFeeMinor,
        equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
      ),
    );
  }

  List<InstallmentSchedulePlanEntry> plan(InstallmentPlanConfig config) {
    if (config.remainingPrincipal.minorUnits < 0) {
      throw ArgumentError.value(
        config.remainingPrincipal.minorUnits,
        'remainingPrincipal',
        'Must be >= 0',
      );
    }
    if (config.firstPeriodNo <= 0) {
      throw ArgumentError.value(
        config.firstPeriodNo,
        'firstPeriodNo',
        'Must be > 0',
      );
    }
    final periods = config.accrualPeriods;
    final dates =
        periods?.map((period) => period.repaymentDate).toList() ??
        config.repaymentDates!.getDates();
    if (dates.isEmpty) {
      throw ArgumentError.value(dates, 'repaymentDates', 'Must not be empty');
    }
    final calculationPeriods =
        periods == null
            ? _calculationPeriodsForDates(config.accrualStartDate!, dates)
            : _calculationPeriodsForAccrualPeriods(periods);
    final calculator = _calculators[config.repaymentMethod];
    if (calculator == null) {
      throw StateError('No calculator for ${config.repaymentMethod}.');
    }
    final allocations = calculator.calculate(
      RepaymentMethodCalculationInput(
        principal: config.remainingPrincipal,
        periods: calculationPeriods,
        accrualMethod: config.interestAccrualMethod,
        ratePeriod: config.interestRatePeriod,
        ratePpm: config.interestRatePpm,
        remainingFeeMinor: config.remainingFeeMinor,
        equalInstallmentOverrideMinor: config.equalInstallmentOverrideMinor,
      ),
    );
    return [
      for (var i = 0; i < dates.length; i++)
        InstallmentSchedulePlanEntry(
          periodNo: config.firstPeriodNo + i,
          expectedRepaymentDate: dates[i],
          expectedPrincipal: allocations[i].principal,
          expectedInterest: allocations[i].interest,
          expectedFee: allocations[i].fee,
        ),
    ];
  }

  List<RepaymentMethodCalculationPeriod> _calculationPeriodsForDates(
    DateTime anchorDate,
    List<DateTime> dates,
  ) {
    final result = <RepaymentMethodCalculationPeriod>[];
    var prev = anchorDate;
    for (final date in dates) {
      final days = date.difference(prev).inDays;
      if (days < 1) {
        throw ArgumentError.value(
          dates,
          'repaymentDates',
          'Must be strictly increasing after the accrual start date',
        );
      }
      result.add(
        RepaymentMethodCalculationPeriod(
          dayCount: days,
          additionalOutstandingPrincipal: Money.zero(),
        ),
      );
      prev = date;
    }
    return result;
  }

  List<RepaymentMethodCalculationPeriod> _calculationPeriodsForAccrualPeriods(
    List<InstallmentAccrualPeriod> periods,
  ) {
    return [
      for (final period in periods)
        RepaymentMethodCalculationPeriod(
          dayCount: _positiveDayCount(
            period.accrualStartDate,
            period.repaymentDate,
            periods,
          ),
          additionalOutstandingPrincipal: period.additionalOutstandingPrincipal,
        ),
    ];
  }

  int _positiveDayCount(
    DateTime accrualStartDate,
    DateTime repaymentDate,
    Object invalidValue,
  ) {
    final days = repaymentDate.difference(accrualStartDate).inDays;
    if (days < 1) {
      throw ArgumentError.value(
        invalidValue,
        'repaymentDates',
        'Must be strictly increasing after the accrual start date',
      );
    }
    return days;
  }
}
