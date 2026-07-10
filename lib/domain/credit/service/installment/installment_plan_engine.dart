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
  });

  final Money remainingPrincipal;
  final int firstPeriodNo;
  final DateTime accrualStartDate;
  final RepaymentDatesStrategy repaymentDates;
  final InstallmentRepaymentMethod repaymentMethod;
  final InterestAccrualMethod interestAccrualMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final int remainingFeeMinor;
  final int? equalInstallmentOverrideMinor;
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
    final dates = config.repaymentDates.getDates();
    if (dates.isEmpty) {
      throw ArgumentError.value(dates, 'repaymentDates', 'Must not be empty');
    }
    final dayCounts = _dayCountsForDates(config.accrualStartDate, dates);
    final calculator = _calculators[config.repaymentMethod];
    if (calculator == null) {
      throw StateError('No calculator for ${config.repaymentMethod}.');
    }
    final allocations = calculator.calculate(
      RepaymentMethodCalculationInput(
        principal: config.remainingPrincipal,
        dayCounts: dayCounts,
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

  List<int> _dayCountsForDates(DateTime anchorDate, List<DateTime> dates) {
    final result = <int>[];
    var prev = anchorDate;
    for (final date in dates) {
      final days = date.difference(prev).inDays;
      result.add(days < 1 ? 1 : days);
      prev = date;
    }
    return result;
  }
}
