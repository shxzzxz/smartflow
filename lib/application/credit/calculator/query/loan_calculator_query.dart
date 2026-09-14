import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../../../domain/credit/service/installment/calculator/installment_metrics.dart'
    show InstallmentMetricsCalculator;
import '../../../../domain/credit/service/installment/installment_plan_engine.dart';
import '../../../../domain/credit/valobj/installment_plan_operation.dart';
import '../../../../domain/credit/valobj/credit_error_code.dart';
import '../../../../domain/credit/valobj/floating_rate.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/installment_plan_terms.dart';
import '../../../../domain/credit/valobj/reference_rate.dart';
import '../../installment/query/contract_metrics_read_model.dart';
import 'loan_calculator_read_model.dart';

class LoanChangeSimulationRequest {
  const LoanChangeSimulationRequest({
    required this.terms,
    required this.operations,
  });

  /// 包含免还期和还款阶段的完整条款。
  final InstallmentPlanTerms terms;

  final InstallmentPlanOperations operations;
}

/// 不落库地生成贷款计划，并组合本金扣减、重定价和利息调整试算变更。
abstract interface class LoanCalculatorQuery {
  LoanCalculation calculate(InstallmentPlanTerms terms);

  LoanChangeSimulation simulateChanges(LoanChangeSimulationRequest request);
}

class LoanCalculatorQueryImpl implements LoanCalculatorQuery {
  const LoanCalculatorQueryImpl({
    InstallmentPlanEngine engine = const InstallmentPlanEngine(),
    InstallmentMetricsCalculator metrics = const InstallmentMetricsCalculator(),
  }) : _engine = engine,
       _metrics = metrics;

  final InstallmentPlanEngine _engine;
  final InstallmentMetricsCalculator _metrics;

  @override
  LoanCalculation calculate(InstallmentPlanTerms terms) {
    final plan = _engine.generate(terms);
    final periods = _periods(terms.principal, plan.entries);
    return LoanCalculation(
      isRateProjection: terms.stages.whereType<AmortizingStage>().any(
        (s) => s.floatingRate != null,
      ),
      periods: periods,
      stages: _stages(terms, plan),
      totalPrincipal: _sum(periods, (period) => period.principal),
      totalInterest: _sum(periods, (period) => period.interest),
      totalFee: _sum(periods, (period) => period.fee),
      metrics: ContractMetrics.fromDomain(
        _metrics.compute(
          principal: terms.principal,
          borrowingDate: terms.borrowingDate,
          plan: plan.entries,
        ),
      ),
    );
  }

  @override
  LoanChangeSimulation simulateChanges(LoanChangeSimulationRequest request) {
    final terms = request.terms;
    if (terms.isCustom) _invalid('自定义还款计划不支持变更试算');
    final original = calculate(terms);
    final operations = InstallmentPlanOperations(
      principalReductions: List.unmodifiable(
        request.operations.principalReductions,
      ),
      rateChangesByStage: Map<int, List<RateChange>>.unmodifiable({
        for (final entry in request.operations.rateChangesByStage.entries)
          entry.key: List<RateChange>.unmodifiable(entry.value),
      }),
      interestAdjustments: List.unmodifiable(
        request.operations.interestAdjustments,
      ),
    );
    for (final reduction in operations.principalReductions) {
      if (reduction.principal.minorUnits <= 0) _invalid('提前还本金必须大于零');
    }
    for (final entry in operations.rateChangesByStage.entries) {
      if (entry.key < 0 ||
          entry.key >= terms.stages.length ||
          terms.stages[entry.key] is! AmortizingStage) {
        _invalid('重定价所属还款阶段不存在');
      }
      final stage = terms.stages[entry.key] as AmortizingStage;
      if (stage.method == InstallmentRepaymentMethod.flatFee) {
        _invalid('一次性手续费阶段不支持重定价');
      }
      final end = referenceDate(stage.dates.getDates().last);
      for (final change in entry.value) {
        final date = referenceDate(change.effectiveDate);
        if (date.isBefore(referenceDate(terms.borrowingDate)) ||
            date.isAfter(end)) {
          _invalid('重定价生效日不得早于借款日或晚于所属阶段末期还款日');
        }
      }
    }
    final plan = _engine.generate(terms, operations: operations);
    final periods = _periods(
      terms.principal,
      plan.entries,
      reductions: operations.principalReductions,
    );
    return LoanChangeSimulation(
      original: original,
      operations: operations,
      periods: periods,
      stages: _stages(terms, plan),
      totalInterest: _sum(periods, (period) => period.interest),
      totalFee: _sum(periods, (period) => period.fee),
    );
  }

  List<LoanCalculationStage> _stages(
    InstallmentPlanTerms terms,
    InstallmentPlan plan,
  ) {
    final indexes = [
      for (var i = 0; i < terms.stages.length; i++)
        if (terms.stages[i] is AmortizingStage) i,
    ];
    return [
      for (var i = 0; i < plan.stages.length; i++)
        LoanCalculationStage(
          index: indexes[i],
          firstPeriodNo: plan.stages[i].firstPeriodNo,
          lastPeriodNo: plan.stages[i].lastPeriodNo,
          installmentAmount: plan.stages[i].installmentAmount,
          lastPeriodDifference: plan.stages[i].lastPeriodDifference,
        ),
    ];
  }

  List<LoanCalculationPeriod> _periods(
    Money principal,
    List<InstallmentSchedulePlanEntry> entries, {
    List<PrincipalReduction> reductions = const [],
  }) {
    final ordered = [...reductions]
      ..sort((a, b) => referenceDate(a.date).compareTo(referenceDate(b.date)));
    var reductionIndex = 0;
    var remaining = principal;
    return [
      for (final entry in entries)
        () {
          while (reductionIndex < ordered.length &&
              !referenceDate(
                ordered[reductionIndex].date,
              ).isAfter(referenceDate(entry.expectedRepaymentDate))) {
            remaining -= ordered[reductionIndex++].principal;
          }
          remaining -= entry.expectedPrincipal;
          return LoanCalculationPeriod(
            periodNo: entry.periodNo,
            date: entry.expectedRepaymentDate,
            principal: entry.expectedPrincipal,
            interest: entry.expectedInterest,
            fee: entry.expectedFee,
            remainingPrincipal: remaining,
          );
        }(),
    ];
  }

  Money _sum<T>(Iterable<T> items, Money Function(T item) amount) {
    return items.fold(Money.zero(), (sum, item) => sum + amount(item));
  }

  Never _invalid(String message) => throw BusinessException(
    CreditErrorCode.contractInvalidCommand,
    message: message,
  );
}
