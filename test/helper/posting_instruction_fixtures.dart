import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';

ExpenseInstruction singleExpenseInstruction({
  required Money amount,
  required String paidFromAccountId,
  required String expenseAccountId,
  required DateTime occurredAt,
  DateTime? postedAt,
  String? counterpartyId,
  String? note,
  bool isExcludedFromStats = false,
  bool isExcludedFromBudget = false,
  SourceKind sourceKind = SourceKind.manual,
  TransactionOwnership? ownership,
}) => ExpenseInstruction(
  amount: amount,
  categoryAllocations: singleAllocation(
    accountId: expenseAccountId,
    amount: amount,
  ),
  settlementAllocations: singleAllocation(
    accountId: paidFromAccountId,
    amount: amount,
  ),
  occurredAt: occurredAt,
  postedAt: postedAt,
  counterpartyId: counterpartyId,
  note: note,
  isExcludedFromStats: isExcludedFromStats,
  isExcludedFromBudget: isExcludedFromBudget,
  sourceKind: sourceKind,
  ownership: ownership,
);

AdvanceInstruction singleAdvanceInstruction({
  required Money amount,
  Money? advanceAmount,
  required String receivableAccountId,
  required String paidFromAccountId,
  required String expenseAccountId,
  required DateTime occurredAt,
  DateTime? postedAt,
  String? counterpartyId,
  String? note,
  bool isExcludedFromStats = false,
  bool isExcludedFromBudget = false,
  SourceKind sourceKind = SourceKind.manual,
  TransactionOwnership? ownership,
}) {
  final nextAdvanceAmount = advanceAmount ?? amount;
  final selfBorneAmount = amount - nextAdvanceAmount;
  return AdvanceInstruction(
    amount: amount,
    advanceAmount: nextAdvanceAmount,
    receivableAccountId: receivableAccountId,
    categoryAllocations: singleAllocation(
      accountId: expenseAccountId,
      amount: amount,
    ),
    selfBorneAllocations: selfBorneAmount.minorUnits == 0
        ? const []
        : singleAllocation(
            accountId: expenseAccountId,
            amount: selfBorneAmount,
          ),
    settlementAllocations: singleAllocation(
      accountId: paidFromAccountId,
      amount: amount,
    ),
    occurredAt: occurredAt,
    postedAt: postedAt,
    counterpartyId: counterpartyId,
    note: note,
    isExcludedFromStats: isExcludedFromStats,
    isExcludedFromBudget: isExcludedFromBudget,
    sourceKind: sourceKind,
    ownership:
        ownership ??
        const TransactionOwnership(
          ownerType: 'orchestration.advance',
          ownerId: 'test-advance',
        ),
  );
}

RefundInstruction singleRefundInstruction({
  required String parentTransactionId,
  required Money amount,
  required String refundToAccountId,
  required DateTime occurredAt,
  List<AccountAmountAllocation> selfBorneAllocations = const [],
  DateTime? postedAt,
  String? counterpartyId,
  String? note,
}) => RefundInstruction(
  parentTransactionId: parentTransactionId,
  amount: amount,
  categoryAllocations: const [],
  selfBorneAllocations: selfBorneAllocations,
  settlementAllocations: singleAllocation(
    accountId: refundToAccountId,
    amount: amount,
  ),
  occurredAt: occurredAt,
  postedAt: postedAt,
  counterpartyId: counterpartyId,
  note: note,
);

AdvanceCollectionInstruction singleAdvanceCollectionInstruction({
  required String advanceTransactionId,
  required Money amount,
  required String receivableAccountId,
  required String receiveAccountId,
  required DateTime occurredAt,
  DateTime? postedAt,
  String? counterpartyId,
  String? note,
}) => AdvanceCollectionInstruction(
  advanceTransactionId: advanceTransactionId,
  amount: amount,
  receivableAccountId: receivableAccountId,
  settlementAllocations: singleAllocation(
    accountId: receiveAccountId,
    amount: amount,
  ),
  occurredAt: occurredAt,
  postedAt: postedAt,
  counterpartyId: counterpartyId,
  note: note,
);

AdvanceSettlementInstruction singleAdvanceSettlementInstruction({
  required String advanceTransactionId,
  required Money actualReceivedAmount,
  required String receivableAccountId,
  required String receiveAccountId,
  required DateTime occurredAt,
  List<AccountAmountAllocation> gapExpenseAllocations = const [],
  AdvanceShortfallKind shortfallKind = AdvanceShortfallKind.selfBorne,
  DateTime? postedAt,
  String? counterpartyId,
  String? note,
}) => AdvanceSettlementInstruction(
  advanceTransactionId: advanceTransactionId,
  actualReceivedAmount: actualReceivedAmount,
  receivableAccountId: receivableAccountId,
  settlementAllocations: singleAllocation(
    accountId: receiveAccountId,
    amount: actualReceivedAmount,
  ),
  gapExpenseAllocations: gapExpenseAllocations,
  shortfallKind: shortfallKind,
  occurredAt: occurredAt,
  postedAt: postedAt,
  counterpartyId: counterpartyId,
  note: note,
);
