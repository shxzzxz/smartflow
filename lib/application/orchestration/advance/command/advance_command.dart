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

sealed class ExpenseSceneTarget {
  const ExpenseSceneTarget();
}

final class OrdinaryExpenseSceneTarget extends ExpenseSceneTarget {
  const OrdinaryExpenseSceneTarget();
}

final class ItemizedAdvanceSceneTarget extends ExpenseSceneTarget {
  const ItemizedAdvanceSceneTarget({
    required this.scenario,
    required this.aaPeopleCount,
    required this.receivableAccountId,
  });

  final AdvanceScenario scenario;
  final int aaPeopleCount;
  final String receivableAccountId;
}

final class AccountAdvanceSceneTarget extends ExpenseSceneTarget {
  const AccountAdvanceSceneTarget({
    required this.scenario,
    required this.aaPeopleCount,
    required this.receivableAccountId,
  });

  final AdvanceScenario scenario;
  final int aaPeopleCount;
  final String receivableAccountId;
}

class CreateExpenseSceneWorkflowCommand {
  CreateExpenseSceneWorkflowCommand({
    required this.amount,
    required this.target,
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
  final ExpenseSceneTarget target;
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

class EditExpenseSceneWorkflowCommand {
  const EditExpenseSceneWorkflowCommand({
    required this.transactionId,
    required this.target,
    this.amount,
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
  final ExpenseSceneTarget target;
  final Money? amount;
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
    required this.advanceTransactionId,
    required this.receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : settlementAllocations = List.unmodifiable(settlementAllocations);

  final Money amount;
  final String advanceTransactionId;
  final String receivableAccountId;
  final List<AccountAmountAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
}

class CreateAdvanceSettlementWorkflowCommand {
  CreateAdvanceSettlementWorkflowCommand({
    required this.actualReceivedAmount,
    required this.advanceTransactionId,
    required this.receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required List<AccountAmountAllocation> gapExpenseAllocations,
    this.shortfallKind = AdvanceShortfallKind.selfBorne,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : settlementAllocations = List.unmodifiable(settlementAllocations),
       gapExpenseAllocations = List.unmodifiable(gapExpenseAllocations);

  final Money actualReceivedAmount;
  final String advanceTransactionId;
  final String receivableAccountId;
  final List<AccountAmountAllocation> settlementAllocations;
  final List<AccountAmountAllocation> gapExpenseAllocations;
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
