import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../../../domain/credit/service/installment/installment_metrics.dart'
    show InstallmentMetricsCalculator;
import '../../../../domain/credit/service/installment/installment_plan_engine.dart';
import '../../../../domain/credit/service/installment/installment_prepayment_recalculator.dart';
import '../../../../domain/credit/valobj/credit_error_code.dart';
import '../../../../domain/credit/valobj/installment_plan_terms.dart';
import '../../installment/query/contract_metrics_read_model.dart';
import 'loan_calculator_read_model.dart';

class LoanPrepaymentSimulationRequest {
  const LoanPrepaymentSimulationRequest({
    required this.terms,
    required this.paidPeriods,
    required this.prepaymentDate,
    required this.prepaymentPrincipal,
  });

  /// 只支持单个摊还阶段的条款。
  final InstallmentPlanTerms terms;

  /// 已按原计划还清的期数（从第 1 期起连续）。
  final int paidPeriods;
  final DateTime prepaymentDate;
  final Money prepaymentPrincipal;
}

/// 贷款计算器：不落库地生成还款计划与合同维度指标，并按重算锚点规则试算提前还款。
abstract interface class LoanCalculatorQuery {
  LoanCalculation calculate(InstallmentPlanTerms terms);

  LoanPrepaymentSimulation simulatePrepayment(
    LoanPrepaymentSimulationRequest request,
  );
}

class LoanCalculatorQueryImpl implements LoanCalculatorQuery {
  const LoanCalculatorQueryImpl({
    InstallmentPlanEngine engine = const InstallmentPlanEngine(),
    InstallmentPrepaymentRecalculator recalculator =
        const InstallmentPrepaymentRecalculator(),
    InstallmentMetricsCalculator metrics = const InstallmentMetricsCalculator(),
  }) : _engine = engine,
       _recalculator = recalculator,
       _metrics = metrics;

  final InstallmentPlanEngine _engine;
  final InstallmentPrepaymentRecalculator _recalculator;
  final InstallmentMetricsCalculator _metrics;

  @override
  LoanCalculation calculate(InstallmentPlanTerms terms) {
    final plan = _engine.plan(terms);
    final periods = _periods(terms.principal, plan.entries);
    final amortizingIndexes = [
      for (var i = 0; i < terms.stages.length; i++)
        if (terms.stages[i] is AmortizingStage) i,
    ];
    return LoanCalculation(
      periods: periods,
      stages: [
        for (var i = 0; i < plan.stages.length; i++)
          LoanCalculationStage(
            index: amortizingIndexes[i],
            firstPeriodNo: plan.stages[i].firstPeriodNo,
            lastPeriodNo: plan.stages[i].lastPeriodNo,
            installmentAmount: plan.stages[i].installmentAmount,
            lastPeriodDifference: plan.stages[i].lastPeriodDifference,
          ),
      ],
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
  LoanPrepaymentSimulation simulatePrepayment(
    LoanPrepaymentSimulationRequest request,
  ) {
    final terms = request.terms;
    final stage = _singleAmortizingStage(terms);
    final base = _engine.plan(terms);
    if (request.paidPeriods < 0 || request.paidPeriods >= base.entries.length) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Paid periods must be fewer than the total periods.',
      );
    }
    if (request.prepaymentPrincipal.minorUnits <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Prepayment principal must be positive.',
      );
    }
    final recalculations = _recalculator.recalculateRows(
      terms: InstallmentRecalculationTerms(
        principal: terms.principal,
        borrowingDate: terms.borrowingDate,
        method: stage.method,
        accrual: stage.accrual,
        rate: stage.rate,
        totalFee: stage.fee,
        installmentAmount: stage.installmentAmount,
        dayCount: terms.dayCount,
        rounding: terms.rounding,
        intervalMonths: stage.dates.intervalMonths,
      ),
      rows: [
        for (final entry in base.entries)
          InstallmentRecalculationRow(
            id: '${entry.periodNo}',
            periodNo: entry.periodNo,
            date: entry.expectedRepaymentDate,
            principal: entry.expectedPrincipal,
            interest: entry.expectedInterest,
            fee: entry.expectedFee,
            isPending: entry.periodNo > request.paidPeriods,
          ),
      ],
      prepaymentPrincipal: request.prepaymentPrincipal,
      eventDate: request.prepaymentDate,
    );
    final recalculatedByPeriodNo = {
      for (final recalculation in recalculations)
        recalculation.periodNo: recalculation,
    };
    final entries = [
      for (final entry in base.entries)
        switch (recalculatedByPeriodNo[entry.periodNo]) {
          null => entry,
          final recalculation => InstallmentSchedulePlanEntry(
            periodNo: recalculation.periodNo,
            expectedRepaymentDate: recalculation.expectedRepaymentDate,
            expectedPrincipal: recalculation.expectedPrincipal,
            expectedInterest: recalculation.expectedInterest,
            expectedFee: recalculation.expectedFee,
          ),
        },
    ];
    // 提前还款本金在锚点当日归还，剩余本金口径从锚点之后开始扣减。
    final periods = _periods(
      terms.principal,
      entries,
      prepayment: (
        principal: request.prepaymentPrincipal,
        beforePeriodNo: recalculations.isEmpty
            ? null
            : recalculations.first.periodNo,
      ),
    );
    final baseInterest = _sum(base.entries, (entry) => entry.expectedInterest);
    final totalInterest = _sum(periods, (period) => period.interest);
    return LoanPrepaymentSimulation(
      periods: periods,
      prepaymentPrincipal: request.prepaymentPrincipal,
      totalInterest: totalInterest,
      totalFee: _sum(periods, (period) => period.fee),
      interestSaved: baseInterest - totalInterest,
      firstRecalculatedPeriodNo: recalculations.isEmpty
          ? null
          : recalculations.first.periodNo,
    );
  }

  AmortizingStage _singleAmortizingStage(InstallmentPlanTerms terms) {
    if (terms.stages.length == 1 && terms.stages.single is AmortizingStage) {
      return terms.stages.single as AmortizingStage;
    }
    throw BusinessException(
      CreditErrorCode.contractInvalidCommand,
      message:
          'Prepayment simulation only supports terms with a single amortizing stage.',
    );
  }

  List<LoanCalculationPeriod> _periods(
    Money principal,
    List<InstallmentSchedulePlanEntry> entries, {
    ({Money principal, int? beforePeriodNo})? prepayment,
  }) {
    var remaining = principal;
    return [
      for (final entry in entries)
        () {
          if (prepayment != null &&
              prepayment.beforePeriodNo == entry.periodNo) {
            remaining -= prepayment.principal;
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
}
