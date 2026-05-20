import '../../../core/money/money.dart';
import '../enums/installment_enums.dart';

class InstallmentContract {
  const InstallmentContract({
    required this.id,
    required this.liabilityAccountId,
    required this.sourceType,
    required this.principal,
    required this.totalPeriods,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    required this.lastRepaymentDate,
    required this.repaymentMethod,
    required this.interestAccrualMethod,
    required this.totalFeeMinor,
    required this.status,
    required this.createdAt,
    this.disbursementAccountId,
    this.disbursementTransactionId,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.note,
  });

  final int id;
  final int liabilityAccountId;
  final InstallmentSourceType sourceType;
  final int? disbursementAccountId;
  final int? disbursementTransactionId;
  final Money principal;
  final int totalPeriods;

  /// 借款日期（放款分期 = 放款交易日；账单分期 = 合同起算日）。
  /// 决定第一期利息天数计算的起点，创建后不可变更。
  final DateTime borrowingDate;

  /// 首期还款日。
  final DateTime firstRepaymentDate;

  /// 末期还款日。默认 = 首期 + (totalPeriods - 1) 月，可独立调整。
  final DateTime lastRepaymentDate;

  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;

  /// 计息方式（按日 / 按月）。决定还款计划的利息计算口径。
  final InterestAccrualMethod interestAccrualMethod;

  /// 合同的总手续费（minor units），用于编辑时按 method 重新分配。
  final int totalFeeMinor;

  final InstallmentContractStatus status;
  final String? note;
  final DateTime createdAt;
}
