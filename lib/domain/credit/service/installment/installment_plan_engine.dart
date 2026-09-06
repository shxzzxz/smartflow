import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/rounding_mode.dart';
import '../../valobj/credit_error_code.dart';
import '../../valobj/equal_installment_amount.dart';
import '../../valobj/installment_enums.dart';
import '../../valobj/installment_plan_terms.dart';
import '../../valobj/interest_rate.dart';
import '../../valobj/repayment_dates_strategy.dart';
import 'interest_accrual_policy.dart';
import 'repayment_method_calculator.dart';

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

/// 一个摊还阶段的计算结果摘要。
class InstallmentStagePlan {
  const InstallmentStagePlan({
    required this.firstPeriodNo,
    required this.lastPeriodNo,
    this.installmentAmount,
    this.lastPeriodDifference,
  });

  final int firstPeriodNo;
  final int lastPeriodNo;

  /// 等额本息实际采用的固定额；其他方式为空。
  final Money? installmentAmount;

  /// 末期本息合计与固定额的差额（正数表示末期多还）；仅等额本息有值。
  final Money? lastPeriodDifference;
}

class InstallmentPlan {
  const InstallmentPlan({required this.entries, required this.stages});

  final List<InstallmentSchedulePlanEntry> entries;
  final List<InstallmentStagePlan> stages;
}

/// 还款计划引擎：按阶段循环组装日期、期次与金额。
///
/// 合同创建、预览、重算与贷款计算器都经由 [plan]；[generate] 与 [allocate]
/// 是现有单阶段合同的适配入口，保持折现法、30/360 与四舍五入的既有口径。
class InstallmentPlanEngine {
  const InstallmentPlanEngine({
    Map<InstallmentRepaymentMethod, RepaymentMethodCalculator>? calculators,
  }) : _calculators = calculators ?? _defaultCalculators;

  /// 一次性手续费是"等额本金 + 免息 + 阶段手续费"的预设，共用等额本金计算器。
  static const _defaultCalculators = {
    InstallmentRepaymentMethod.equalInstallment: EqualInstallmentCalculator(),
    InstallmentRepaymentMethod.equalPrincipal: EqualPrincipalCalculator(),
    InstallmentRepaymentMethod.interestFirst: InterestFirstCalculator(),
    InstallmentRepaymentMethod.flatFee: EqualPrincipalCalculator(),
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
    final entries = plan(
      singleStageTerms(
        principal: remainingPrincipal,
        accrualStartDate: anchorDate,
        dates: ExplicitRepaymentDates(pendingDates),
        method: method,
        accrualMethod: accrualMethod,
        ratePeriod: ratePeriod,
        ratePpm: ratePpm,
        feeMinor: remainingFeeMinor,
        equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
      ),
    ).entries;
    return [
      for (final entry in entries)
        InstallmentAmountAllocation(
          principal: entry.expectedPrincipal,
          interest: entry.expectedInterest,
          fee: entry.expectedFee,
        ),
    ];
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
      singleStageTerms(
        principal: principal,
        accrualStartDate: borrowingDate,
        dates: IntervalRepaymentDates(
          firstDate: firstRepaymentDate,
          count: totalPeriods,
          lastDate: lastRepaymentDate,
        ),
        method: method,
        accrualMethod: accrualMethod,
        ratePeriod: ratePeriod,
        ratePpm: ratePpm,
        feeMinor: totalFeeMinor,
        equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
      ),
    ).entries;
  }

  /// 现有合同的单阶段条款：折现法求固定额（给定固定额时采用给定值）、30/360、四舍五入。
  static InstallmentPlanTerms singleStageTerms({
    required Money principal,
    required DateTime accrualStartDate,
    required RepaymentDatesStrategy dates,
    required InstallmentRepaymentMethod method,
    required InterestAccrualMethod accrualMethod,
    InterestRatePeriod? ratePeriod,
    int? ratePpm,
    int feeMinor = 0,
    int? equalInstallmentOverrideMinor,
  }) {
    return InstallmentPlanTerms(
      principal: principal,
      borrowingDate: accrualStartDate,
      stages: [
        AmortizingStage(
          dates: dates,
          method: method,
          rate: InterestRate.maybe(ratePeriod, ratePpm),
          accrual: accrualMethod,
          fee: Money(minorUnits: feeMinor),
          installmentAmount:
              equalInstallmentOverrideMinor != null &&
                  equalInstallmentOverrideMinor > 0
              ? EqualInstallmentAmount.fixed(
                  Money(minorUnits: equalInstallmentOverrideMinor),
                )
              : const EqualInstallmentAmount.actualRate(),
        ),
      ],
    );
  }

  InstallmentPlan plan(
    InstallmentPlanTerms terms, {
    int firstPeriodNo = 1,
    bool capEndPrincipal = false,
  }) {
    if (terms.principal.minorUnits < 0) {
      throw _invalid('Principal must not be negative.');
    }
    if (terms.stages.isEmpty) {
      throw _invalid('At least one stage is required.');
    }
    if (firstPeriodNo <= 0) {
      throw ArgumentError.value(firstPeriodNo, 'firstPeriodNo', 'Must be > 0');
    }
    final policy = InterestAccrualPolicy(dayCount: terms.dayCount);
    final entries = <InstallmentSchedulePlanEntry>[];
    final stagePlans = <InstallmentStagePlan>[];
    var timelineDate = terms.borrowingDate;
    var openingPrincipal = terms.principal;
    var periodNo = firstPeriodNo;
    for (var index = 0; index < terms.stages.length; index++) {
      final stage = terms.stages[index];
      final isLastStage = index == terms.stages.length - 1;
      switch (stage) {
        case DefermentStage(:final until):
          if (!_dateOnly(until).isAfter(_dateOnly(timelineDate))) {
            throw _invalid('Deferment must end after the previous stage.');
          }
          timelineDate = until;
        case AmortizingStage():
          final result = _planStage(
            stage,
            policy: policy,
            rounding: terms.rounding,
            capEndPrincipal: capEndPrincipal,
            openingPrincipal: openingPrincipal,
            timelineDate: timelineDate,
            isLastStage: isLastStage,
            firstPeriodNo: periodNo,
          );
          entries.addAll(result.entries);
          stagePlans.add(result.summary);
          timelineDate = result.entries.last.expectedRepaymentDate;
          openingPrincipal = result.closingPrincipal;
          periodNo += result.entries.length;
      }
    }
    if (entries.isEmpty) {
      throw _invalid('At least one amortizing stage is required.');
    }
    // 自定义合同先生成占位行，再由用户填写本金；自动计划必须一次分配全部本金。
    final hasCustomStage = terms.stages.any(
      (stage) =>
          stage is AmortizingStage &&
          stage.method == InstallmentRepaymentMethod.custom,
    );
    final allocatedPrincipal = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.expectedPrincipal.minorUnits,
    );
    if (!hasCustomStage && allocatedPrincipal != terms.principal.minorUnits) {
      throw _invalid('The plan must allocate the entire principal.');
    }
    return InstallmentPlan(entries: entries, stages: stagePlans);
  }

  _StageResult _planStage(
    AmortizingStage stage, {
    required InterestAccrualPolicy policy,
    required RoundingMode rounding,
    required bool capEndPrincipal,
    required Money openingPrincipal,
    required DateTime timelineDate,
    required bool isLastStage,
    required int firstPeriodNo,
  }) {
    final dates = stage.dates.getDates();
    if (dates.isEmpty) {
      throw ArgumentError.value(dates, 'repaymentDates', 'Must not be empty');
    }
    if (!_dateOnly(dates.first).isAfter(_dateOnly(timelineDate))) {
      throw _invalid(
        'Repayment dates must be strictly increasing across stages.',
      );
    }
    final accrualStart = stage.accrualStartDate ?? timelineDate;
    final spans = <AccrualPeriodSpan>[];
    var previous = accrualStart;
    for (final date in dates) {
      final days = _daysBetween(previous, date);
      if (days < 1) {
        throw _invalid(
          'Repayment dates must be strictly increasing after the accrual start date.',
        );
      }
      spans.add(
        AccrualPeriodSpan(days: days, months: stage.dates.intervalMonths),
      );
      previous = date;
    }

    final isFlatFee = stage.method == InstallmentRepaymentMethod.flatFee;
    final method = isFlatFee
        ? InstallmentRepaymentMethod.equalPrincipal
        : stage.method;
    final rate = isFlatFee ? null : stage.rate;
    final requestedEndPrincipal = _endPrincipal(
      stage,
      method,
      openingPrincipal,
      isLastStage,
    );
    final endPrincipal =
        capEndPrincipal &&
            requestedEndPrincipal.minorUnits > openingPrincipal.minorUnits
        ? openingPrincipal
        : requestedEndPrincipal;
    if (endPrincipal.minorUnits < 0 ||
        endPrincipal.minorUnits > openingPrincipal.minorUnits) {
      throw _invalid(
        'End principal must be between zero and the opening principal.',
      );
    }
    final balloon =
        isLastStage &&
        stage.endPrincipal != null &&
        endPrincipal.minorUnits > 0;
    final calculator = _calculators[method];
    if (calculator == null) {
      throw StateError('No calculator for $method.');
    }
    // 零本金分摊时按余额计息，指定固定额不能反推出额外本金。
    final effectiveCalculator =
        capEndPrincipal &&
            endPrincipal.minorUnits == openingPrincipal.minorUnits
        ? const InterestFirstCalculator()
        : calculator;
    final calculation = effectiveCalculator.calculate(
      RepaymentMethodCalculationInput(
        openingPrincipal: openingPrincipal,
        endPrincipal: endPrincipal,
        rates: [
          for (final span in spans)
            policy.periodRate(rate: rate, accrual: stage.accrual, span: span),
        ],
        rounding: rounding,
        installmentAmount: stage.installmentAmount,
      ),
    );
    if (stage.fee.minorUnits < 0) {
      throw _invalid('Stage fee must not be negative.');
    }
    final fees = splitEvenly(stage.fee.minorUnits, dates.length, rounding);

    final entries = <InstallmentSchedulePlanEntry>[];
    for (var i = 0; i < dates.length; i++) {
      final allocation = calculation.allocations[i];
      final isLastPeriod = i == dates.length - 1;
      entries.add(
        InstallmentSchedulePlanEntry(
          periodNo: firstPeriodNo + i,
          expectedRepaymentDate: dates[i],
          expectedPrincipal: balloon && isLastPeriod
              ? allocation.principal + endPrincipal
              : allocation.principal,
          expectedInterest: allocation.interest,
          expectedFee: Money(minorUnits: fees[i]),
        ),
      );
    }
    final installmentAmount = calculation.installmentAmount;
    final last = entries.last;
    return _StageResult(
      entries: entries,
      closingPrincipal: balloon ? Money.zero() : endPrincipal,
      summary: InstallmentStagePlan(
        firstPeriodNo: firstPeriodNo,
        lastPeriodNo: last.periodNo,
        installmentAmount: installmentAmount,
        lastPeriodDifference: installmentAmount == null
            ? null
            : last.expectedPrincipal +
                  last.expectedInterest -
                  installmentAmount,
      ),
    );
  }

  Money _endPrincipal(
    AmortizingStage stage,
    InstallmentRepaymentMethod method,
    Money openingPrincipal,
    bool isLastStage,
  ) {
    final explicit = stage.endPrincipal;
    if (explicit != null) return explicit;
    if (isLastStage) return Money.zero();
    if (method == InstallmentRepaymentMethod.interestFirst) {
      return openingPrincipal;
    }
    throw _invalid(
      'Non-final stages of this repayment method require an explicit end principal.',
    );
  }

  static int _daysBetween(DateTime from, DateTime to) {
    return _dateOnly(to).difference(_dateOnly(from)).inDays;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime.utc(value.year, value.month, value.day);
  }

  static BusinessException _invalid(String message) {
    return BusinessException(
      CreditErrorCode.contractInvalidCommand,
      message: message,
    );
  }
}

class _StageResult {
  const _StageResult({
    required this.entries,
    required this.closingPrincipal,
    required this.summary,
  });

  final List<InstallmentSchedulePlanEntry> entries;
  final Money closingPrincipal;
  final InstallmentStagePlan summary;
}
