import '../../../../../core/money/money.dart';
import '../../../valobj/floating_rate.dart';
import '../../../valobj/installment_enums.dart';
import '../../../valobj/reference_rate.dart';
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
    required List<int> reductions,
    required List<RateChange> changes,
  }) {
    final generation = BasePlanGenerationHandler(calculators: _calculators);
    final principalHandler = PrincipalReductionHandler(generation);
    final repricingHandler = RepricingHandler(generation);
    // 首期内及此前免还期的扣减都从本阶段计息起点生效。
    final opening = principalHandler.deduct(openingPrincipal, reductions.first);
    var balance = opening;
    var target = generation.endPrincipalFor(
      context.stage,
      openingPrincipal: opening,
      finalStage: finalStage,
    );
    var rate = context.stage.method == InstallmentRepaymentMethod.flatFee
        ? null
        : context.stage.rate;
    var previous = referenceDate(context.start);
    InstallmentStageProjection? projection;
    var changed = false;
    Money? fixedAmount;
    final allocations = <InstallmentAmountAllocation>[];

    for (var i = 0; i < context.dates.length; i++) {
      final openingRate = repricingHandler.rateAt(rate, previous, changes);
      if (openingRate != rate) {
        projection = null;
        changed = true;
      }
      rate = openingRate;
      if (i > 0 && reductions[i] != 0) {
        final reduction = principalHandler.recalculate(
          context,
          periodIndex: i,
          openingPrincipal: balance,
          endPrincipal: target,
          reductionMinor: reductions[i],
          rate: rate,
        );
        balance = reduction.principal;
        target = reduction.endPrincipal;
        projection = reduction.projection;
        changed = true;
      }
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
      allocations.add(repricing.allocation);
      balance -= repricing.allocation.principal;
      rate = repricing.closingRate;
      previous = referenceDate(context.dates[i]);
    }
    return InstallmentStageCalculation(
      openingPrincipal: opening,
      closingPrincipal: balance,
      calculation: RepaymentMethodCalculation(
        allocations: List.unmodifiable(allocations),
        installmentAmount: changed ? null : fixedAmount,
      ),
    );
  }
}
