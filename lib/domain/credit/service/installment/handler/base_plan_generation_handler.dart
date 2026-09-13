import '../../../../../core/error/app_exception.dart';
import '../../../../../core/money/money.dart';
import '../../../valobj/credit_error_code.dart';
import '../../../valobj/installment_enums.dart';
import '../../../valobj/installment_plan_terms.dart';
import '../../../valobj/interest_rate.dart';
import '../../../valobj/reference_rate.dart';
import '../calculator/interest_accrual_policy.dart';
import '../calculator/repayment_method_calculator.dart';
import 'installment_stage_context.dart';

/// 剩余期次的一次本息求解结果，期序相对于完整阶段。
class InstallmentStageProjection {
  const InstallmentStageProjection({
    required this.firstPeriodIndex,
    required this.calculation,
  });

  final int firstPeriodIndex;
  final RepaymentMethodCalculation calculation;

  InstallmentAmountAllocation allocationAt(int periodIndex) =>
      calculation.allocations[periodIndex - firstPeriodIndex];
}

/// 组织剩余期限的计息输入，选择还款方式 Calculator 并生成基础本息。
class BasePlanGenerationHandler {
  const BasePlanGenerationHandler({
    Map<InstallmentRepaymentMethod, RepaymentMethodCalculator>? calculators,
  }) : _calculators = calculators ?? _defaultCalculators;

  static const _defaultCalculators = {
    InstallmentRepaymentMethod.equalInstallment: EqualInstallmentCalculator(),
    InstallmentRepaymentMethod.equalPrincipal: EqualPrincipalCalculator(),
    InstallmentRepaymentMethod.interestFirst: InterestFirstCalculator(),
    InstallmentRepaymentMethod.flatFee: EqualPrincipalCalculator(),
  };
  final Map<InstallmentRepaymentMethod, RepaymentMethodCalculator> _calculators;

  Money endPrincipalFor(
    AmortizingStage stage, {
    required Money openingPrincipal,
    required bool finalStage,
  }) {
    final requested =
        stage.endPrincipal ??
        (finalStage
            ? Money.zero()
            : stage.method == InstallmentRepaymentMethod.interestFirst
            ? openingPrincipal
            : _invalid('非末阶段必须约定期末本金'));
    if (requested.minorUnits < 0) _invalid('期末本金不得为负');
    return requested.minorUnits > openingPrincipal.minorUnits
        ? openingPrincipal
        : requested;
  }

  InstallmentStageProjection generate(
    InstallmentStageContext context, {
    required int periodIndex,
    required Money openingPrincipal,
    required Money endPrincipal,
    required InterestRate? rate,
    PeriodRate? firstPeriodRate,
  }) {
    final stage = context.stage;
    final configured = _calculators[stage.method];
    if (configured == null) {
      throw StateError('No calculator for ${stage.method}');
    }
    final calculator = openingPrincipal == endPrincipal
        ? const InterestFirstCalculator()
        : configured;
    var from = periodIndex == 0
        ? context.start
        : context.dates[periodIndex - 1];
    final rates = <PeriodRate>[];
    for (var i = periodIndex; i < context.dates.length; i++) {
      final until = context.dates[i];
      rates.add(
        i == periodIndex && firstPeriodRate != null
            ? firstPeriodRate
            : context.policy.periodRate(
                rate: rate,
                accrual: stage.accrual,
                span: AccrualPeriodSpan(
                  days: referenceDate(
                    until,
                  ).difference(referenceDate(from)).inDays,
                  months: stage.dates.intervalMonths,
                ),
                start: from,
                end: until,
                units: context.accrualUnits,
                elapsedMonths: i * stage.dates.intervalMonths,
              ),
      );
      from = until;
    }
    return InstallmentStageProjection(
      firstPeriodIndex: periodIndex,
      calculation: calculator.calculate(
        RepaymentMethodCalculationInput(
          openingPrincipal: openingPrincipal,
          endPrincipal: endPrincipal,
          rates: rates,
          rounding: context.rounding,
          installmentAmount: stage.installmentAmount,
        ),
      ),
    );
  }

  static Never _invalid(String message) => throw BusinessException(
    CreditErrorCode.contractInvalidCommand,
    message: message,
  );
}
