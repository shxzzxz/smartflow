import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../valobj/credit_error_code.dart';
import '../../valobj/installment_enums.dart';
import '../../valobj/installment_plan_operation.dart';
import '../../valobj/installment_plan_terms.dart';
import '../../valobj/interest_accrual_segment.dart';
import '../../valobj/reference_rate.dart';
import 'calculator/interest_accrual_policy.dart';
import 'calculator/repayment_method_calculator.dart';
import 'handler/fee_allocation_handler.dart';
import 'handler/final_principal_settlement_handler.dart';
import 'handler/installment_stage_context.dart';
import 'handler/installment_stage_handler.dart';
import 'handler/interest_adjustment_handler.dart';

class InstallmentSchedulePlanEntry {
  const InstallmentSchedulePlanEntry({
    required this.periodNo,
    this.stageIndex = 0,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    this.interestSegments = const [],
  });

  final int periodNo;
  final int stageIndex;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal, expectedInterest, expectedFee;
  final List<InterestAccrualSegment> interestSegments;

  InstallmentSchedulePlanEntry withInterest(Money interest) =>
      InstallmentSchedulePlanEntry(
        periodNo: periodNo,
        stageIndex: stageIndex,
        expectedRepaymentDate: expectedRepaymentDate,
        expectedPrincipal: expectedPrincipal,
        expectedInterest: interest,
        expectedFee: expectedFee,
        interestSegments: interestSegments,
      );
}

class InstallmentStagePlan {
  const InstallmentStagePlan({
    required this.firstPeriodNo,
    required this.lastPeriodNo,
    this.installmentAmount,
    this.lastPeriodDifference,
    this.openingPrincipal,
    this.closingPrincipal,
  });

  final int firstPeriodNo, lastPeriodNo;
  final Money? installmentAmount, lastPeriodDifference;
  final Money? openingPrincipal, closingPrincipal;
}

class InstallmentPlan {
  InstallmentPlan({
    required List<InstallmentSchedulePlanEntry> entries,
    required List<InstallmentStagePlan> stages,
  }) : entries = List.unmodifiable(entries),
       stages = List.unmodifiable(stages);

  final List<InstallmentSchedulePlanEntry> entries;
  final List<InstallmentStagePlan> stages;
}

/// 生成与重算共用的纯计算入口。只消费完整条款和有效操作，不读取旧计划或状态。
class InstallmentPlanEngine {
  const InstallmentPlanEngine({
    Map<InstallmentRepaymentMethod, RepaymentMethodCalculator>? calculators,
  }) : _calculators = calculators;

  final Map<InstallmentRepaymentMethod, RepaymentMethodCalculator>?
  _calculators;

  InstallmentPlan generate(
    InstallmentPlanTerms terms, {
    InstallmentPlanOperations operations = const InstallmentPlanOperations(),
  }) {
    if (terms.principal.minorUnits < 0 || terms.stages.isEmpty) {
      _invalid('本金不得为负，至少需要一个阶段');
    }
    terms.validateStageKinds();
    final custom = terms.isCustom;
    final reductions = [...operations.principalReductions]
      ..sort((a, b) => referenceDate(a.date).compareTo(referenceDate(b.date)));
    final rateChanges = {
      for (final entry in operations.rateChangesByStage.entries)
        entry.key: [...entry.value]
          ..sort(
            (a, b) => referenceDate(
              a.effectiveDate,
            ).compareTo(referenceDate(b.effectiveDate)),
          ),
    };
    for (final entry in rateChanges.entries) {
      if (entry.key < 0 ||
          entry.key >= terms.stages.length ||
          terms.stages[entry.key] is! AmortizingStage) {
        _invalid('重定价必须属于本合同的还款阶段');
      }
      final effectiveDates = <DateTime>{};
      for (final change in entry.value) {
        change.validate();
        if (!effectiveDates.add(referenceDate(change.effectiveDate))) {
          _invalid('同一合同同一阶段同一生效日最多一条有效重定价记录');
        }
      }
    }
    if (!custom) {
      for (final reduction in reductions) {
        if (reduction.principal.minorUnits < 0 ||
            referenceDate(
              reduction.date,
            ).isBefore(referenceDate(terms.borrowingDate))) {
          _invalid('本金扣减金额不得为负，发生日期不得早于借款日');
        }
      }
    }
    final policy = InterestAccrualPolicy(dayCount: terms.dayCount);
    final stageHandler = InstallmentStageHandler(calculators: _calculators);
    final entries = <InstallmentSchedulePlanEntry>[];
    final summaries = <InstallmentStagePlan>[];
    var timeline = referenceDate(terms.borrowingDate);
    var opening = terms.principal;
    var reductionIndex = 0;
    for (var index = 0; index < terms.stages.length; index++) {
      final stage = terms.stages[index];
      if (stage is DefermentStage) {
        if (!referenceDate(stage.until).isAfter(timeline)) {
          _invalid('免还期结束日必须晚于前一阶段');
        }
        timeline = referenceDate(stage.until);
        continue;
      }
      final repayment = stage as AmortizingStage;
      final dates = repayment.dates.getDates();
      var previous = timeline;
      for (final date in dates) {
        if (!referenceDate(date).isAfter(previous)) _invalid('计划日期必须按期序严格递增');
        previous = referenceDate(date);
      }
      if (dates.isEmpty) _invalid('还款阶段至少需要一期');
      final start = referenceDate(repayment.accrualStartDate ?? timeline);
      if (start.isBefore(timeline) ||
          !referenceDate(dates.first).isAfter(start)) {
        _invalid('计息起点必须位于前一阶段结束日至首期还款日之间');
      }
      final firstPeriod = entries.length + 1;
      final fees = const FeeAllocationHandler().allocate(
        fee: repayment.fee,
        periodCount: dates.length,
        rounding: terms.rounding,
        tailDifference: repayment.tailDifference,
      );
      if (custom) {
        for (var i = 0; i < dates.length; i++) {
          entries.add(
            InstallmentSchedulePlanEntry(
              periodNo: entries.length + 1,
              stageIndex: index,
              expectedRepaymentDate: dates[i],
              expectedPrincipal: Money.zero(),
              expectedInterest: Money.zero(),
              expectedFee: fees[i],
            ),
          );
        }
        summaries.add(
          InstallmentStagePlan(
            firstPeriodNo: firstPeriod,
            lastPeriodNo: entries.length,
          ),
        );
        timeline = referenceDate(dates.last);
        continue;
      }

      repayment.validateFloatingRate();
      final context = InstallmentStageContext(
        stage: repayment,
        dates: dates,
        start: start,
        policy: policy,
        rounding: terms.rounding,
      );
      final deductions = <int>[];
      for (var i = 0; i < dates.length; i++) {
        var amount = 0;
        // 还款后的计息日期才受影响；恰在本期还款日扣减时归入下一期。
        while (reductionIndex < reductions.length &&
            referenceDate(reductions[reductionIndex].date)
                .add(const Duration(days: 1))
                .isBefore(context.periodRange(i).end)) {
          amount += reductions[reductionIndex++].principal.minorUnits;
        }
        deductions.add(amount);
      }
      final finalStage = index == terms.stages.length - 1;
      final stageCalculation = stageHandler.calculate(
        context,
        openingPrincipal: opening,
        finalStage: finalStage,
        reductions: deductions,
        changes: repayment.method == InstallmentRepaymentMethod.flatFee
            ? []
            : rateChanges[index] ?? [],
      );
      final calculation = stageCalculation.calculation;
      final settlement = const FinalPrincipalSettlementHandler().settle(
        allocations: calculation.allocations,
        closingPrincipal: stageCalculation.closingPrincipal,
        finalStage: finalStage,
      );
      for (var i = 0; i < dates.length; i++) {
        final allocation = settlement.allocations[i];
        entries.add(
          InstallmentSchedulePlanEntry(
            periodNo: entries.length + 1,
            stageIndex: index,
            expectedRepaymentDate: dates[i],
            expectedPrincipal: allocation.principal,
            expectedInterest: allocation.interest,
            expectedFee: fees[i],
            interestSegments: List.unmodifiable(allocation.interestSegments),
          ),
        );
      }
      final last = entries.last;
      summaries.add(
        InstallmentStagePlan(
          firstPeriodNo: firstPeriod,
          lastPeriodNo: last.periodNo,
          openingPrincipal: stageCalculation.openingPrincipal,
          closingPrincipal: stageCalculation.closingPrincipal,
          installmentAmount: calculation.installmentAmount,
        ),
      );
      opening = settlement.remainingPrincipal;
      timeline = referenceDate(dates.last);
    }
    if (entries.isEmpty) _invalid('至少需要一个还款阶段');
    if (!custom) {
      if (reductionIndex != reductions.length) _invalid('本金扣减日期必须早于末期还款日');
      final principal = entries.fold<int>(
        0,
        (sum, row) => sum + row.expectedPrincipal.minorUnits,
      );
      final deducted = reductions.fold<int>(
        0,
        (sum, reduction) => sum + reduction.principal.minorUnits,
      );
      if (principal + deducted != terms.principal.minorUnits) {
        _invalid('计划本金与本金扣减合计必须等于合同本金');
      }
      const adjustmentHandler = InterestAdjustmentHandler();
      adjustmentHandler.validate(
        operations.interestAdjustments,
        entries.expand((row) => row.interestSegments),
      );
      if (operations.interestAdjustments.isNotEmpty) {
        for (var i = 0; i < entries.length; i++) {
          final entry = entries[i];
          entries[i] = entry.withInterest(
            adjustmentHandler.apply(
              entry.interestSegments,
              operations.interestAdjustments,
              terms.rounding,
            ),
          );
        }
      }
    }
    return InstallmentPlan(
      entries: entries,
      stages: [
        for (final summary in summaries)
          InstallmentStagePlan(
            firstPeriodNo: summary.firstPeriodNo,
            lastPeriodNo: summary.lastPeriodNo,
            openingPrincipal: summary.openingPrincipal,
            closingPrincipal: summary.closingPrincipal,
            installmentAmount: summary.installmentAmount,
            lastPeriodDifference: summary.installmentAmount == null
                ? null
                : entries[summary.lastPeriodNo - 1].expectedPrincipal +
                      entries[summary.lastPeriodNo - 1].expectedInterest -
                      summary.installmentAmount!,
          ),
      ],
    );
  }

  static Never _invalid(String message) => throw BusinessException(
    CreditErrorCode.contractInvalidCommand,
    message: message,
  );
}
