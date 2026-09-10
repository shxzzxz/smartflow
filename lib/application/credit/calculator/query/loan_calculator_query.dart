import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../../../domain/credit/service/installment/installment_metrics.dart'
    show InstallmentMetricsCalculator;
import '../../../../domain/credit/service/installment/installment_plan_engine.dart';
import '../../../../domain/credit/valobj/installment_plan_change.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/credit_error_code.dart';
import '../../../../domain/credit/valobj/installment_contract_terms.dart';
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

  /// 包含免还期和还款阶段的完整条款。
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
  LoanPrepaymentSimulation simulatePrepayment(
    LoanPrepaymentSimulationRequest request,
  ) {
    final terms = request.terms;
    final base = _engine.generate(terms);
    if (request.paidPeriods < 0 || request.paidPeriods >= base.entries.length) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '已还期数必须少于总期数',
      );
    }
    if (request.prepaymentPrincipal.minorUnits <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '提前还本金必须大于零',
      );
    }
    if (request.prepaymentDate.isBefore(terms.borrowingDate)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '提前还款日不能早于借款日期',
      );
    }
    final contractTerms = InstallmentContractTerms(
      stages: [
        for (var i = 0; i < terms.stages.length; i++)
          InstallmentContractStage(id: 'stage-$i', terms: terms.stages[i]),
      ],
      dayCount: terms.dayCount,
      rounding: terms.rounding,
      tailDifference: terms.tailDifference,
    );
    final change = _engine.recalculate(
      InstallmentPlanContext(
        terms: contractTerms,
        principal: terms.principal,
        borrowingDate: terms.borrowingDate,
        rows: [
          for (final entry in base.entries)
            InstallmentPlanRow(
              id: '${entry.periodNo}',
              stageId: 'stage-${entry.stageIndex}',
              periodNo: entry.periodNo,
              date: entry.expectedRepaymentDate,
              principal: entry.expectedPrincipal,
              interest: entry.expectedInterest,
              fee: entry.expectedFee,
              status: entry.periodNo > request.paidPeriods
                  ? InstallmentScheduleStatus.pending
                  : InstallmentScheduleStatus.paid,
            ),
        ],
        prepaymentPrincipal: request.prepaymentPrincipal,
      ),
      RecalculateAfterPrepayment(request.prepaymentDate),
    );
    final recalculations = change.recalculatedRows;
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
            expectedRepaymentDate: recalculation.date,
            expectedPrincipal: recalculation.principal,
            expectedInterest: recalculation.interest,
            expectedFee: recalculation.fee,
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
    final baseFee = _sum(base.entries, (entry) => entry.expectedFee);
    final totalInterest = _sum(periods, (period) => period.interest);
    return LoanPrepaymentSimulation(
      isRateProjection: request.terms.stages.whereType<AmortizingStage>().any(
        (s) => s.floatingRate != null,
      ),
      periods: periods,
      stages: _stages(terms, base),
      prepaymentPrincipal: request.prepaymentPrincipal,
      totalInterest: totalInterest,
      totalFee: _sum(periods, (period) => period.fee),
      interestSaved: baseInterest - totalInterest,
      firstRecalculatedPeriodNo: recalculations.isEmpty
          ? null
          : recalculations.first.periodNo,
      paidPeriods: request.paidPeriods,
      beforeTotalInterest: baseInterest,
      beforeTotalFee: baseFee,
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
