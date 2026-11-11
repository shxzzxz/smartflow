import '../../../valobj/rate_change.dart';
import '../../../valobj/installment_plan_operation.dart';
import '../../../valobj/reference_rate.dart';
import '../../../../../core/money/money.dart';
import '../../../valobj/installment_enums.dart';
import '../calculator/repayment_method_calculator.dart';
import 'base_plan_generation_handler.dart';
import 'installment_stage_context.dart';
import 'principal_reduction_handler.dart';
import 'repricing_handler.dart';

class InstallmentStageCalculation {
  const InstallmentStageCalculation({
    required this.openingPrincipal,
    required this.closingPrincipal,
    required this.calculation,
  });

  final Money openingPrincipal;

  /// 正常摊还后的余额，尚未追加末阶段尾款。
  final Money closingPrincipal;
  final RepaymentMethodCalculation calculation;
}

/// 按期序调度基础生成、本金扣减和重定价，传递当前余额与适用利率。
class InstallmentStageHandler {
  const InstallmentStageHandler({
    Map<InstallmentRepaymentMethod, RepaymentMethodCalculator>? calculators,
  }) : _calculators = calculators;

  final Map<InstallmentRepaymentMethod, RepaymentMethodCalculator>?
  _calculators;

  InstallmentStageCalculation calculate(
    InstallmentStageContext context, {
    required Money openingPrincipal,
    required bool finalStage,
    required List<List<PrincipalReduction>> reductions,
    required List<DateTime?> interestSettledThrough,
    required List<RateChange> changes,
  }) {
    final generation = BasePlanGenerationHandler(calculators: _calculators);
    const principalHandler = PrincipalReductionHandler();
    final repricingHandler = RepricingHandler(generation);
    final opening = openingPrincipal;
    var stageOpening = opening;
    var balance = opening;
    var target = generation.endPrincipalFor(
      context.stage,
      openingPrincipal: opening,
      finalStage: finalStage,
    );
    var rate = context.stage.method == InstallmentRepaymentMethod.flatFee
        ? null
        : context.stage.rate;
    InstallmentStageProjection? projection;
    var changed = false;
    Money? fixedAmount;
    final allocations = <InstallmentAmountAllocation>[];

    for (var i = 0; i < context.dates.length; i++) {
      final range = context.periodRange(i);
      final openingReductions = [
        for (final reduction in reductions[i])
          if (!referenceDate(
            reduction.date,
          ).add(const Duration(days: 1)).isAfter(range.start))
            reduction,
      ];
      final openingReductionMinor = openingReductions.fold<int>(
        0,
        (sum, reduction) => sum + reduction.principal.minorUnits,
      );
      if (openingReductionMinor > 0) {
        balance = principalHandler.deduct(balance, openingReductionMinor);
        if (target.minorUnits > balance.minorUnits) target = balance;
        projection = null;
        changed = true;
        if (i == 0) stageOpening = balance;
      }
      final inPeriodReductions = [
        for (final reduction in reductions[i])
          if (referenceDate(
                reduction.date,
              ).add(const Duration(days: 1)).isAfter(range.start) &&
              referenceDate(
                reduction.date,
              ).add(const Duration(days: 1)).isBefore(range.end))
            reduction,
      ];
      final openingRate = repricingHandler.rateAt(rate, range.start, changes);
      if (!repricingHandler.hasSameRate(context, openingRate, rate)) {
        projection = null;
        changed = true;
      }
      rate = openingRate;
      projection ??= generation.generate(
        context,
        periodIndex: i,
        openingPrincipal: balance,
        endPrincipal: target,
        rate: rate,
      );
      fixedAmount ??= projection.calculation.installmentAmount;
      final repricing = repricingHandler.apply(
        context,
        periodIndex: i,
        openingPrincipal: balance,
        endPrincipal: target,
        openingRate: rate,
        projection: projection,
        changes: changes,
      );
      projection = repricing.projection;
      changed = changed || repricing.changed;
      var allocation = repricing.allocation;
      final settledThrough = interestSettledThrough[i];
      if (inPeriodReductions.isNotEmpty || settledThrough != null) {
        final reduction = principalHandler.applyInPeriod(
          context,
          periodIndex: i,
          openingPrincipal: balance,
          openingRate: rate,
          changes: changes,
          reductions: inPeriodReductions,
          currentAllocation: allocation,
          rounding: context.rounding,
          interestSettledThrough: settledThrough,
        );
        allocation = reduction.allocation;
        balance -=
            allocation.principal + Money(minorUnits: reduction.reductionMinor);
        if (target.minorUnits > balance.minorUnits) target = balance;
        projection = null;
        changed = true;
      } else {
        balance -= allocation.principal;
      }
      allocations.add(allocation);
      rate = repricing.closingRate;
    }
    return InstallmentStageCalculation(
      openingPrincipal: stageOpening,
      closingPrincipal: balance,
      calculation: RepaymentMethodCalculation(
        allocations: List.unmodifiable(allocations),
        installmentAmount: changed ? null : fixedAmount,
      ),
    );
  }
}
