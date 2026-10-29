import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import '../../../../domain/credit/valobj/installment_contract_terms.dart';

class CreateDisbursementContractCommand {
  const CreateDisbursementContractCommand({
    this.name,
    required this.liabilityAccountId,
    required this.principal,
    required this.borrowingDate,
    this.disbursementAccountId,
    this.note,
    this.counterpartyId,
    required this.stageTerms,
  });

  final String liabilityAccountId;
  final String? name;

  /// 放款入账账户。为空时用于迁移场景：只创建合同和计划，不创建放款交易。
  final String? disbursementAccountId;
  final Money principal;

  /// 借款日期，同时作为放款交易的 occurredAt。
  final DateTime borrowingDate;

  final String? note;
  final String? counterpartyId;
  final InstallmentContractTerms stageTerms;
}

class ConsumptionInstallmentAllocation {
  const ConsumptionInstallmentAllocation({
    required this.accountId,
    required this.amount,
  });

  final String accountId;
  final Money amount;
}

class CreateConsumptionInstallmentCommand {
  CreateConsumptionInstallmentCommand({
    this.name,
    required this.liabilityAccountId,
    required this.amount,
    required List<ConsumptionInstallmentAllocation> categoryAllocations,
    required List<ConsumptionInstallmentAllocation> settlementAllocations,
    required this.borrowingDate,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.tagIds = const {},
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    required this.stageTerms,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final String? name;
  final String liabilityAccountId;
  final Money amount;
  final List<ConsumptionInstallmentAllocation> categoryAllocations;
  final List<ConsumptionInstallmentAllocation> settlementAllocations;
  final DateTime borrowingDate;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final Set<String> tagIds;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final InstallmentContractTerms stageTerms;
}

class CreateConsumptionInstallmentRefundCommand {
  CreateConsumptionInstallmentRefundCommand({
    required this.contractId,
    required this.parentTransactionId,
    required this.amount,
    required List<ConsumptionInstallmentAllocation> categoryAllocations,
    required List<ConsumptionInstallmentAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final String contractId;
  final String parentTransactionId;
  final Money amount;
  final List<ConsumptionInstallmentAllocation> categoryAllocations;
  final List<ConsumptionInstallmentAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
}

class EditConsumptionInstallmentRefundCommand {
  EditConsumptionInstallmentRefundCommand({
    required this.transactionId,
    required this.contractId,
    required this.parentTransactionId,
    this.amount,
    List<ConsumptionInstallmentAllocation>? categoryAllocations,
    List<ConsumptionInstallmentAllocation>? settlementAllocations,
    this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : categoryAllocations = categoryAllocations == null
           ? null
           : List.unmodifiable(categoryAllocations),
       settlementAllocations = settlementAllocations == null
           ? null
           : List.unmodifiable(settlementAllocations);

  final String transactionId;
  final String contractId;
  final String parentTransactionId;
  final Money? amount;
  final List<ConsumptionInstallmentAllocation>? categoryAllocations;
  final List<ConsumptionInstallmentAllocation>? settlementAllocations;
  final DateTime? occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;

  bool get hasFinancialEdit =>
      amount != null ||
      categoryAllocations != null ||
      settlementAllocations != null ||
      occurredAt != null;
}

class DeleteConsumptionInstallmentRefundCommand {
  const DeleteConsumptionInstallmentRefundCommand({
    required this.transactionId,
  });

  final String transactionId;
}

class ConsumptionInstallmentRefundResult {
  const ConsumptionInstallmentRefundResult({
    required this.refundTransactionId,
    required this.principalReduction,
  });

  final String refundTransactionId;
  final Money principalReduction;
}

class DeleteContractCommand {
  const DeleteContractCommand({required this.contractId});

  final String contractId;
}

/// 只生成重算预览；确认通过合同编辑用例提交预览指纹。
class PreviewContractRecalculationCommand {
  const PreviewContractRecalculationCommand({
    required this.contractId,
    this.stageTerms,
  });
  final String contractId;
  final InstallmentContractTerms? stageTerms;
}

class ContractRecalculationPreview {
  const ContractRecalculationPreview({
    required this.schedules,
    required this.token,
  });
  final List<RecalculatedSchedulePreview> schedules;
  final String token;
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

  final String? scheduleId;
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
/// - 借款日期在创建后不可修改。
/// - 默认只更新参数快照；[regeneratePlan] 为 true 时用 [planPreviewToken] 确认重算。
/// - [schedulePatches] 只覆盖对应 pending 行；paid / skipped 行不可编辑。
///
/// Partial update 约定：
/// - 普通 nullable 字段（`T?`）：`null` 表示"不改"，传值表示"设置"。
/// - 三态字段（`Patch<T>?`）：`null`=不改，`Patch.set`=设置，`Patch.clear`=清除。
/// - `disbursementAccountId`：仅对已有放款交易的放款合同有效；业务上禁止清除。
class UpdateContractDetailsCommand {
  const UpdateContractDetailsCommand({
    required this.contractId,
    this.name,
    this.disbursementAccountId,
    this.note,
  });

  final String contractId;
  final String? name;
  final String? disbursementAccountId;
  final Patch<String>? note;
}

class RecalculateContractPlanCommand {
  const RecalculateContractPlanCommand({
    required this.contractId,
    required this.stageTerms,
    required this.planPreviewToken,
  });

  final String contractId;
  final InstallmentContractTerms stageTerms;
  final String planPreviewToken;
}

class PatchInstallmentScheduleCommand {
  const PatchInstallmentScheduleCommand({
    required this.contractId,
    required this.schedulePatches,
  });

  final String contractId;
  final List<SchedulePendingPatch> schedulePatches;
}

/// 合同编辑用例的组合命令。
class UpdateContractCommand {
  const UpdateContractCommand({
    required this.contractId,
    this.name,
    this.disbursementAccountId,
    this.note,
    this.schedulePatches = const [],
    this.stageTerms,
    this.regeneratePlan = false,
    this.planPreviewToken,
  });

  final String contractId;
  final String? name;

  /// 放款合同的放款账户。仅对 sourceType=disbursement 的合同有效。
  /// 业务上禁止清除（账单分期合同永远 null，放款合同永远有值）。
  final String? disbursementAccountId;

  final Patch<String>? note;
  final List<SchedulePendingPatch> schedulePatches;
  final InstallmentContractTerms? stageTerms;
  final bool regeneratePlan;
  final String? planPreviewToken;
}

class CreateContractResult {
  const CreateContractResult({
    required this.contractId,
    this.disbursementTransactionId,
    this.purchaseTransactionId,
  });

  final String contractId;
  final String? disbursementTransactionId;
  final String? purchaseTransactionId;
}
