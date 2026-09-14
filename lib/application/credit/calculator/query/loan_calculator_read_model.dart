import '../../../../core/money/money.dart';
import '../../../../domain/credit/valobj/installment_plan_operation.dart';
import '../../installment/query/contract_metrics_read_model.dart';

class LoanCalculationPeriod {
  const LoanCalculationPeriod({
    required this.periodNo,
    required this.date,
    required this.principal,
    required this.interest,
    required this.fee,
    required this.remainingPrincipal,
  });

  final int periodNo;
  final DateTime date;
  final Money principal;
  final Money interest;
  final Money fee;

  /// 本期还款后剩余本金。
  final Money remainingPrincipal;

  Money get total => principal + interest + fee;
}

class LoanCalculationStage {
  const LoanCalculationStage({
    required this.index,
    required this.firstPeriodNo,
    required this.lastPeriodNo,
    this.installmentAmount,
    this.lastPeriodDifference,
  });

  /// 在条款阶段序列中的位置（含免还期）。
  final int index;
  final int firstPeriodNo;
  final int lastPeriodNo;

  /// 等额本息采用的固定额；其他方式为空。
  final Money? installmentAmount;

  /// 末期本息合计与固定额的差额；仅等额本息有值。
  final Money? lastPeriodDifference;
}

class LoanCalculation {
  const LoanCalculation({
    required this.periods,
    required this.stages,
    required this.totalPrincipal,
    required this.totalInterest,
    required this.totalFee,
    required this.metrics,
    this.isRateProjection = false,
  });

  final List<LoanCalculationPeriod> periods;
  final List<LoanCalculationStage> stages;
  final Money totalPrincipal;
  final Money totalInterest;
  final Money totalFee;
  final ContractMetrics metrics;
  final bool isRateProjection;

  Money get totalRepayment => totalPrincipal + totalInterest + totalFee;
}

class LoanChangeSimulation {
  const LoanChangeSimulation({
    required this.original,
    required this.operations,
    required this.periods,
    required this.stages,
    required this.totalInterest,
    required this.totalFee,
  });

  final LoanCalculation original;
  final InstallmentPlanOperations operations;

  /// 按完整条款和全部操作重新计算的计划。
  final List<LoanCalculationPeriod> periods;
  final List<LoanCalculationStage> stages;
  final Money totalInterest;
  final Money totalFee;

  Money get prepaymentPrincipal => operations.principalReductions.fold(
    Money.zero(),
    (sum, reduction) => sum + reduction.principal,
  );
  Money get beforeCharges => original.totalInterest + original.totalFee;
  Money get afterCharges => totalInterest + totalFee;
  Money get interestChange => totalInterest - original.totalInterest;
  Money get chargesChange => afterCharges - beforeCharges;

  /// 正常计划还款与全部提前还本金共同构成总还款。
  Money get totalRepayment => original.totalPrincipal + afterCharges;
  bool get isRateProjection => original.isRateProjection;
}
