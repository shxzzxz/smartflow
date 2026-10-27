import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

class CreateAdvanceWorkflowCommand {
  CreateAdvanceWorkflowCommand({
    required this.amount,
    required this.scenario,
    required this.trackingMode,
    required this.aaPeopleCount,
    required this.receivableAccountId,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
    this.tagIds = const {},
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final Money amount;
  final AdvanceScenario scenario;
  final AdvanceTrackingMode trackingMode;
  final int aaPeopleCount;
  final String receivableAccountId;
  final List<AccountAmountAllocation> categoryAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;
  final Set<String> tagIds;
}

class EditAdvanceWorkflowCommand {
  EditAdvanceWorkflowCommand({
    required this.transactionId,
    required this.scenario,
    this.aaPeopleCount,
    this.amount,
    this.receivableAccountId,
    this.categoryAllocations,
    this.settlementAllocations,
    this.occurredAt,
    this.counterpartyId,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
    this.tagIds,
  });

  final String transactionId;
  final AdvanceScenario scenario;
  final int? aaPeopleCount;
  final Money? amount;
  final String? receivableAccountId;
  final List<AccountAmountAllocation>? categoryAllocations;
  final List<AccountAmountAllocation>? settlementAllocations;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyId;
  final Patch<String?>? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
  final Set<String>? tagIds;
}

class CreateAdvanceCollectionWorkflowCommand {
  CreateAdvanceCollectionWorkflowCommand({
    required this.amount,
    required String advanceTransactionId,
    required this.receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : advanceTransactionId = advanceTransactionId,
       scenario = null,
       settlementAllocations = List.unmodifiable(settlementAllocations);

  CreateAdvanceCollectionWorkflowCommand.account({
    required this.amount,
    required this.receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required this.scenario,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : advanceTransactionId = null,
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final Money amount;
  final String? advanceTransactionId;
  final String receivableAccountId;
  final List<AccountAmountAllocation> settlementAllocations;
  final AdvanceScenario? scenario;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
}

class CreateAdvanceSettlementWorkflowCommand {
  CreateAdvanceSettlementWorkflowCommand({
    required this.actualReceivedAmount,
    required String advanceTransactionId,
    required this.receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required List<AccountAmountAllocation> gapExpenseAllocations,
    this.shortfallKind = AdvanceShortfallKind.selfBorne,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : advanceTransactionId = advanceTransactionId,
       scenario = null,
       settlementAllocations = List.unmodifiable(settlementAllocations),
       gapExpenseAllocations = List.unmodifiable(gapExpenseAllocations);

  CreateAdvanceSettlementWorkflowCommand.account({
    required this.actualReceivedAmount,
    required this.receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required List<AccountAmountAllocation> gapExpenseAllocations,
    required this.scenario,
    this.shortfallKind = AdvanceShortfallKind.selfBorne,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : advanceTransactionId = null,
       settlementAllocations = List.unmodifiable(settlementAllocations),
       gapExpenseAllocations = List.unmodifiable(gapExpenseAllocations);

  final Money actualReceivedAmount;
  final String? advanceTransactionId;
  final String receivableAccountId;
  final List<AccountAmountAllocation> settlementAllocations;
  final List<AccountAmountAllocation> gapExpenseAllocations;
  final AdvanceScenario? scenario;
  final AdvanceShortfallKind shortfallKind;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
}

class EditAdvanceCollectionWorkflowCommand {
  EditAdvanceCollectionWorkflowCommand({
    required this.transactionId,
    this.amount,
    this.receivableAccountId,
    this.settlementAllocations,
    this.occurredAt,
    this.counterpartyId,
    this.note,
  });

  final String transactionId;
  final Money? amount;
  final String? receivableAccountId;
  final List<AccountAmountAllocation>? settlementAllocations;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyId;
  final Patch<String?>? note;
}

class EditAdvanceSettlementWorkflowCommand {
  EditAdvanceSettlementWorkflowCommand({
    required this.transactionId,
    this.actualReceivedAmount,
    this.receivableAccountId,
    this.settlementAllocations,
    this.gapExpenseAllocations,
    this.shortfallKind,
    this.occurredAt,
    this.counterpartyId,
    this.note,
  });

  final String transactionId;
  final Money? actualReceivedAmount;
  final String? receivableAccountId;
  final List<AccountAmountAllocation>? settlementAllocations;
  final List<AccountAmountAllocation>? gapExpenseAllocations;
  final AdvanceShortfallKind? shortfallKind;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyId;
  final Patch<String?>? note;
}

class CreateAdvanceRefundWorkflowCommand {
  CreateAdvanceRefundWorkflowCommand({
    required this.parentTransactionId,
    required this.amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final String parentTransactionId;
  final Money amount;
  final List<AccountAmountAllocation> categoryAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
}

class EditAdvanceRefundWorkflowCommand {
  EditAdvanceRefundWorkflowCommand({
    required this.transactionId,
    required this.amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.counterpartyId,
    this.note,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final String transactionId;
  final Money amount;
  final List<AccountAmountAllocation> categoryAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final DateTime occurredAt;
  final Patch<String?>? counterpartyId;
  final Patch<String?>? note;
}
