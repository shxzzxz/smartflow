import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';
import '../valobj/amortization_enums.dart';

abstract interface class AmortizationLedgerPort {
  Future<void> validatePlanAccounts({
    required AmortizationKind kind,
    required String deferralAccountId,
    required Iterable<String> categoryAccountIds,
  });

  Future<void> validateRefundAccounts({
    required AmortizationKind kind,
    required Iterable<String> categoryAccountIds,
    required Iterable<String> settlementAccountIds,
  });

  Future<String> postTransfer({
    required Money amount,
    required List<AccountAmountAllocation> outgoingAllocations,
    required List<AccountAmountAllocation> incomingAllocations,
    required DateTime occurredAt,
    DateTime? postedAt,
    Money? feeAmount,
    String? counterpartyId,
    String? note,
    required TransactionOwnership ownership,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    SourceKind sourceKind = SourceKind.manual,
    Set<String> tagIds = const {},
  });

  Future<String> postExpense({
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    String? counterpartyId,
    String? note,
    required TransactionOwnership ownership,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    SourceKind sourceKind = SourceKind.auto,
    Set<String> tagIds = const {},
  });

  Future<String> postIncome({
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    String? counterpartyId,
    String? note,
    required TransactionOwnership ownership,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    SourceKind sourceKind = SourceKind.auto,
    Set<String> tagIds = const {},
  });

  Future<void> rewriteExpense({
    required String transactionId,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
  });

  Future<void> rewriteIncome({
    required String transactionId,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
  });

  Future<void> deleteTransaction(String transactionId);
}
