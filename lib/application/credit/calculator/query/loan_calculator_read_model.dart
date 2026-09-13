import '../../../../core/money/money.dart';
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

class LoanPrepaymentSimulation {
  const LoanPrepaymentSimulation({
    required this.periods,
    this.stages = const [],
    required this.prepaymentPrincipal,
    required this.totalInterest,
    required this.totalFee,
    required this.interestSaved,
    required this.firstRecalculatedPeriodNo,
    this.paidPeriods = 0,
    this.beforeTotalInterest = const Money(minorUnits: 0),
    this.beforeTotalFee = const Money(minorUnits: 0),
    this.isRateProjection = false,
  });

  /// 按完整条款及日期化本金扣减重新计算的计划。
  final List<LoanCalculationPeriod> periods;
  final List<LoanCalculationStage> stages;
  final Money prepaymentPrincipal;
  final Money totalInterest;
  final Money totalFee;

  /// 与原计划相比节省的利息。
  final Money interestSaved;

  /// 第一个被本金扣减影响的计息期次。
  final int? firstRecalculatedPeriodNo;

  /// 用于展示试算背景，不冻结计算范围。
  final int paidPeriods;

  /// 提前还款前的计划息费，用于结果概览。
  final Money beforeTotalInterest;
  final Money beforeTotalFee;
  final bool isRateProjection;

  Money get beforeCharges => beforeTotalInterest + beforeTotalFee;
  Money get afterCharges => totalInterest + totalFee;
  Money get chargesSaved => beforeCharges - afterCharges;
}
