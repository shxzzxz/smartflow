import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';

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

class ConsumptionInstallmentResult {
  const ConsumptionInstallmentResult({
    required this.contractId,
    required this.purchaseTransactionId,
  });

  /// 分期与合同共用的稳定身份。
  final String contractId;
  final String purchaseTransactionId;
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
