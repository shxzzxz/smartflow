import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

class CreateDisbursementContractCommand {
  const CreateDisbursementContractCommand({
    required this.liabilityAccountId,
    required this.principal,
    required this.totalPeriods,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    required this.repaymentMethod,
    this.lastRepaymentDate,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.interestAccrualMethod = InterestAccrualMethod.daily,
    this.totalFeeMinor = 0,
    this.equalInstallmentOverrideMinor,
    this.disbursementAccountId,
    this.note,
    this.counterpartyName,
  });

  final String liabilityAccountId;

  /// 放款入账账户。为空时用于迁移场景：只创建合同和计划，不创建放款交易。
  final String? disbursementAccountId;
  final Money principal;
  final int totalPeriods;

  /// 借款日期，同时作为放款交易的 occurredAt。
  final DateTime borrowingDate;
  final DateTime firstRepaymentDate;

  /// 末期还款日，缺省时 = 首期 + (期数-1) 月。
  final DateTime? lastRepaymentDate;

  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final InterestAccrualMethod interestAccrualMethod;
  final int totalFeeMinor;

  /// 等额本息下用户给定的每期还款额 A（前 N-1 期；末期吸误差）。
  /// 仅生成计划期间使用，**不落库**。null 时回落到公式推导。
  final int? equalInstallmentOverrideMinor;

  final String? note;
  final String? counterpartyName;
}

class DeleteContractCommand {
  const DeleteContractCommand({required this.contractId});

  final String contractId;
}

class RecalculateContractSchedulesCommand {
  const RecalculateContractSchedulesCommand({
    required this.contractId,
    this.terms,
    this.equalInstallmentOverrideMinor,
  });

  final String contractId;
  final ContractRecalculationTerms? terms;

  /// 等额本息下用户给定的每期还款额 A，仅用于本次显式重算，不落库。
  final int? equalInstallmentOverrideMinor;
}

class ContractRecalculationTerms {
  const ContractRecalculationTerms({
    required this.totalPeriods,
    required this.firstRepaymentDate,
    required this.lastRepaymentDate,
    required this.repaymentMethod,
    required this.interestRatePeriod,
    required this.interestRatePpm,
    required this.interestAccrualMethod,
    required this.totalFeeMinor,
  });

  final int totalPeriods;
  final DateTime firstRepaymentDate;
  final DateTime lastRepaymentDate;
  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final InterestAccrualMethod interestAccrualMethod;
  final int totalFeeMinor;
}

class RecalculatedSchedulePreview {
  const RecalculatedSchedulePreview({
    required this.scheduleId,
    required this.periodNo,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
  });

  final String scheduleId;
  final int periodNo;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
}

class SkipInstallmentScheduleCommand {
  const SkipInstallmentScheduleCommand({
    required this.contractId,
    required this.scheduleId,
  });

  final String contractId;
  final String scheduleId;
}

class RestoreInstallmentScheduleCommand {
  const RestoreInstallmentScheduleCommand({
    required this.contractId,
    required this.scheduleId,
  });

  final String contractId;
  final String scheduleId;
}

/// pending 期次的单行手工编辑值（不会改 paid / skipped 行）。
class SchedulePendingPatch {
  const SchedulePendingPatch({
    required this.periodNo,
    this.expectedPrincipal,
    this.expectedInterest,
    this.expectedFee,
    this.expectedRepaymentDate,
  });

  final int periodNo;
  final Money? expectedPrincipal;
  final Money? expectedInterest;
  final Money? expectedFee;
  final DateTime? expectedRepaymentDate;
}

/// 合同编辑命令。
///
/// 编辑范围由 service 校验：
/// - 借款日期可以改；若有放款交易，会联动 disbursement 交易的 occurredAt。
/// - 参数字段只写回合同快照，不会自动重算 schedule。
/// - [schedulePatches] 只覆盖对应 pending 行；paid / skipped 行不可编辑。
///
/// Partial update 约定：
/// - 普通 nullable 字段（`T?`）：`null` 表示"不改"，传值表示"设置"。
/// - 三态字段（`Patch<T>?`）：`null`=不改，`Patch.set`=设置，`Patch.clear`=清除。
/// - `disbursementAccountId`：仅对已有放款交易的放款合同有效；业务上禁止清除。
class UpdateContractCommand {
  const UpdateContractCommand({
    required this.contractId,
    this.totalPeriods,
    this.firstRepaymentDate,
    this.lastRepaymentDate,
    this.borrowingDate,
    this.repaymentMethod,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.interestAccrualMethod,
    this.totalFeeMinor,
    this.equalInstallmentOverrideMinor,
    this.disbursementAccountId,
    this.note,
    this.schedulePatches = const [],
  });

  final String contractId;
  final int? totalPeriods;
  final DateTime? firstRepaymentDate;
  final DateTime? lastRepaymentDate;
  final DateTime? borrowingDate;
  final InstallmentRepaymentMethod? repaymentMethod;
  final Patch<InterestRatePeriod>? interestRatePeriod;
  final Patch<int>? interestRatePpm;
  final InterestAccrualMethod? interestAccrualMethod;
  final int? totalFeeMinor;

  /// 等额本息下用户给定的每期还款额 A，仅重算 pending 期次时使用，**不落库**。
  final int? equalInstallmentOverrideMinor;

  /// 放款合同的放款账户。仅对 sourceType=disbursement 的合同有效。
  /// 业务上禁止清除（账单分期合同永远 null，放款合同永远有值）。
  final String? disbursementAccountId;

  final Patch<String>? note;
  final List<SchedulePendingPatch> schedulePatches;
}

class CreateContractResult {
  const CreateContractResult({
    required this.contractId,
    this.disbursementTransactionId,
  });

  final String contractId;
  final String? disbursementTransactionId;
}
