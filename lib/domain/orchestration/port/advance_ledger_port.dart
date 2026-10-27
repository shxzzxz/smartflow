import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';

abstract interface class AdvanceLedgerPort {
  Future<String> postExpense({
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
    SourceKind sourceKind = SourceKind.manual,
    Set<String> tagIds = const {},
  });

  Future<String> postAdvance({
    required Money amount,
    required Money advanceAmount,
    required String receivableAccountId,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> selfBorneAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required TransactionOwnership ownership,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
    SourceKind sourceKind = SourceKind.manual,
    Set<String> tagIds = const {},
  });

  Future<String> postAdvanceCollection({
    required Money amount,
    required String? advanceTransactionId,
    required String receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required TransactionOwnership? ownership,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
  });

  Future<String> postAdvanceSettlement({
    required Money actualReceivedAmount,
    required String? advanceTransactionId,
    required String receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required List<AccountAmountAllocation> gapExpenseAllocations,
    required AdvanceShortfallKind shortfallKind,
    required TransactionOwnership? ownership,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
  });

  Future<String> rewriteAdvance({
    required String transactionId,
    required Money amount,
    required Money advanceAmount,
    required String receivableAccountId,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> selfBorneAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required TransactionOwnership ownership,
    required Map<String, List<AccountAmountAllocation>>
    refundSelfBorneAllocations,
    required DateTime occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    Set<String>? tagIds,
  });

  Future<String> rewriteExpense({
    required String transactionId,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required Map<String, List<AccountAmountAllocation>>
    refundSelfBorneAllocations,
    required DateTime occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    Set<String>? tagIds,
  });

  Future<String> postRefund({
    required String parentTransactionId,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> selfBorneAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
  });

  Future<String> rewriteRefund({
    required String transactionId,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> selfBorneAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
  });

  Future<String> rewriteAdvanceCollection({
    required String transactionId,
    required Money amount,
    required String receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    TransactionOwnership? ownership,
    required DateTime occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
  });

  Future<String> rewriteAdvanceSettlement({
    required String transactionId,
    required Money actualReceivedAmount,
    required String receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required List<AccountAmountAllocation> gapExpenseAllocations,
    required AdvanceShortfallKind shortfallKind,
    TransactionOwnership? ownership,
    required DateTime occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
  });

  Future<TransactionGroup?> findGroup(String transactionId);
}
