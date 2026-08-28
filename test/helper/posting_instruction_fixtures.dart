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
  String? counterpartyName,
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
  counterpartyName: counterpartyName,
  note: note,
  isExcludedFromStats: isExcludedFromStats,
  isExcludedFromBudget: isExcludedFromBudget,
  sourceKind: sourceKind,
  ownership: ownership,
);

ReimbursementAdvanceInstruction singleReimbursementAdvanceInstruction({
  required Money amount,
  required String receivableAccountId,
  required String paidFromAccountId,
  required String expenseAccountId,
  required DateTime occurredAt,
  DateTime? postedAt,
  String? counterpartyName,
  String? note,
  bool isExcludedFromStats = false,
  bool isExcludedFromBudget = false,
  SourceKind sourceKind = SourceKind.manual,
  TransactionOwnership? ownership,
}) => ReimbursementAdvanceInstruction(
  amount: amount,
  receivableAccountId: receivableAccountId,
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
  counterpartyName: counterpartyName,
  note: note,
  isExcludedFromStats: isExcludedFromStats,
  isExcludedFromBudget: isExcludedFromBudget,
  sourceKind: sourceKind,
  ownership: ownership,
);

RefundInstruction singleRefundInstruction({
  required String parentTransactionId,
  required Money amount,
  required String refundToAccountId,
  required DateTime occurredAt,
  DateTime? postedAt,
  String? counterpartyName,
  String? note,
}) => RefundInstruction(
  parentTransactionId: parentTransactionId,
  amount: amount,
  categoryAllocations: const [],
  settlementAllocations: singleAllocation(
    accountId: refundToAccountId,
    amount: amount,
  ),
  occurredAt: occurredAt,
  postedAt: postedAt,
  counterpartyName: counterpartyName,
  note: note,
);

ReimbursementReceiptInstruction singleReimbursementReceiptInstruction({
  required String advanceTransactionId,
  required Money amount,
  required String receivableAccountId,
  required String receiveAccountId,
  required DateTime occurredAt,
  DateTime? postedAt,
  String? counterpartyName,
  String? note,
}) => ReimbursementReceiptInstruction(
  advanceTransactionId: advanceTransactionId,
  amount: amount,
  receivableAccountId: receivableAccountId,
  settlementAllocations: singleAllocation(
    accountId: receiveAccountId,
    amount: amount,
  ),
  occurredAt: occurredAt,
  postedAt: postedAt,
  counterpartyName: counterpartyName,
  note: note,
);

ReimbursementCloseInstruction singleReimbursementCloseInstruction({
  required String advanceTransactionId,
  required Money actualReceivedAmount,
  required String receivableAccountId,
  required String receiveAccountId,
  required DateTime occurredAt,
  List<AccountAmountAllocation> gapExpenseAllocations = const [],
  DateTime? postedAt,
  String? counterpartyName,
  String? note,
}) => ReimbursementCloseInstruction(
  advanceTransactionId: advanceTransactionId,
  actualReceivedAmount: actualReceivedAmount,
  receivableAccountId: receivableAccountId,
  settlementAllocations: singleAllocation(
    accountId: receiveAccountId,
    amount: actualReceivedAmount,
  ),
  gapExpenseAllocations: gapExpenseAllocations,
  occurredAt: occurredAt,
  postedAt: postedAt,
  counterpartyName: counterpartyName,
  note: note,
);
