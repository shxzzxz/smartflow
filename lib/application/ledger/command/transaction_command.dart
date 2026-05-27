import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';

class CreateExpenseCommand {
  const CreateExpenseCommand({
    required this.amount,
    required this.paidFromAccountId,
    required this.expenseAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final String paidFromAccountId;
  final String expenseAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class CreateIncomeCommand {
  const CreateIncomeCommand({
    required this.amount,
    required this.receiveAccountId,
    required this.incomeAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final String receiveAccountId;
  final String incomeAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class CreateTransferCommand {
  const CreateTransferCommand({
    required this.amount,
    required this.fromAccountId,
    required this.toAccountId,
    required this.occurredAt,
    this.feeAmount,
    this.feeExpenseAccountId,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final String fromAccountId;
  final String toAccountId;
  final DateTime occurredAt;
  final Money? feeAmount;
  final String? feeExpenseAccountId;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class CreateRefundCommand {
  const CreateRefundCommand({
    required this.amount,
    required this.parentTransactionId,
    required this.refundToAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final String parentTransactionId;
  final String refundToAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class CreateReimbursementAdvanceCommand {
  const CreateReimbursementAdvanceCommand({
    required this.amount,
    required this.receivableAccountId,
    required this.paidFromAccountId,
    required this.expenseCategoryId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final String receivableAccountId;
  final String paidFromAccountId;
  final String expenseCategoryId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class CreateReimbursementReceiptCommand {
  const CreateReimbursementReceiptCommand({
    required this.amount,
    required this.advanceTransactionId,
    required this.receivableAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final String advanceTransactionId;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class CloseReimbursementCommand {
  const CloseReimbursementCommand({
    required this.actualReceivedAmount,
    required this.advanceTransactionId,
    required this.receivableAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money actualReceivedAmount;
  final String advanceTransactionId;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class CreateRepaymentCommand {
  const CreateRepaymentCommand({
    required this.principal,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.interest,
    this.fee,
    this.discount,
    this.counterpartyName,
    this.note,
    this.ownership,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final String liabilityAccountId;
  final String paidFromAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final TransactionOwnership? ownership;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class CreateBorrowingCommand {
  const CreateBorrowingCommand({
    required this.amount,
    required this.liabilityAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.ownership,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final String liabilityAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final TransactionOwnership? ownership;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class CreateOpeningBalanceCommand {
  const CreateOpeningBalanceCommand({
    required this.accountId,
    required this.amount,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final String accountId;
  final Money amount;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class AdjustBalanceCommand {
  const AdjustBalanceCommand({
    required this.accountId,
    required this.targetBalance,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final String accountId;
  final Money targetBalance;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class CorrectExpenseCommand {
  const CorrectExpenseCommand({
    required this.transactionId,
    required this.amount,
    required this.paidFromAccountId,
    required this.expenseAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money amount;
  final String paidFromAccountId;
  final String expenseAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class CorrectIncomeCommand {
  const CorrectIncomeCommand({
    required this.transactionId,
    required this.amount,
    required this.receiveAccountId,
    required this.incomeAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money amount;
  final String receiveAccountId;
  final String incomeAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class CorrectTransferCommand {
  const CorrectTransferCommand({
    required this.transactionId,
    required this.amount,
    required this.fromAccountId,
    required this.toAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money amount;
  final String fromAccountId;
  final String toAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class CorrectReimbursementAdvanceCommand {
  const CorrectReimbursementAdvanceCommand({
    required this.transactionId,
    required this.amount,
    required this.receivableAccountId,
    required this.paidFromAccountId,
    required this.expenseCategoryId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money amount;
  final String receivableAccountId;
  final String paidFromAccountId;
  final String expenseCategoryId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class CorrectRefundCommand {
  const CorrectRefundCommand({
    required this.transactionId,
    required this.amount,
    required this.refundToAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money amount;
  final String refundToAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class CorrectReimbursementReceiptCommand {
  const CorrectReimbursementReceiptCommand({
    required this.transactionId,
    required this.amount,
    required this.receivableAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money amount;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class CorrectReimbursementCloseCommand {
  const CorrectReimbursementCloseCommand({
    required this.transactionId,
    required this.actualReceivedAmount,
    required this.receivableAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money actualReceivedAmount;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class CorrectBorrowingCommand {
  const CorrectBorrowingCommand({
    required this.transactionId,
    required this.amount,
    required this.liabilityAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money amount;
  final String liabilityAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class CorrectRepaymentCommand {
  const CorrectRepaymentCommand({
    required this.transactionId,
    required this.principal,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.interest,
    this.fee,
    this.discount,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final String liabilityAccountId;
  final String paidFromAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class DeleteTransactionCommand {
  const DeleteTransactionCommand({required this.transactionId});

  final String transactionId;
}

class UpdateTransactionMetadataCommand {
  const UpdateTransactionMetadataCommand({
    required this.transactionId,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;

  /// `null` 表示不改备注；`Patch.set(value)` 设置；`Patch.clear()` 清空。
  final Patch<String>? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class UpdateTransactionBasicsCommand {
  const UpdateTransactionBasicsCommand({
    required this.transactionId,
    this.occurredAt,
    this.settlementAccountId,
    this.reimbursementAccountId,
  });

  final String transactionId;
  final DateTime? occurredAt;
  final String? settlementAccountId;
  final String? reimbursementAccountId;
}

class UpdateTransactionOwnershipCommand {
  const UpdateTransactionOwnershipCommand({
    required this.transactionId,
    required this.ownership,
  });

  final String transactionId;
  final TransactionOwnership ownership;
}

/// transaction_service 的所有写入命令统一返回此结果。
/// 内部 ledger 的 PostTransactionResult 不对外暴露；service 实现把它映射成本类型。
class CreatedTransactionResult {
  const CreatedTransactionResult({
    required this.transactionId,
    required this.rootTransactionId,
  });

  final String transactionId;
  final String rootTransactionId;
}
