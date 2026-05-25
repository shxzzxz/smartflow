import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import 'package:smartflow/domain/accounting/entities/transaction_ownership.dart';

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
  final int paidFromAccountId;
  final int expenseAccountId;
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
  final int receiveAccountId;
  final int incomeAccountId;
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
  final int fromAccountId;
  final int toAccountId;
  final DateTime occurredAt;
  final Money? feeAmount;
  final int? feeExpenseAccountId;
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
  final int parentTransactionId;
  final int refundToAccountId;
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
  final int receivableAccountId;
  final int paidFromAccountId;
  final int expenseCategoryId;
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
  final int advanceTransactionId;
  final int receivableAccountId;
  final int receiveAccountId;
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
  final int advanceTransactionId;
  final int receivableAccountId;
  final int receiveAccountId;
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
  final int liabilityAccountId;
  final int paidFromAccountId;
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
  final int liabilityAccountId;
  final int receiveAccountId;
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

  final int accountId;
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

  final int accountId;
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

  final int transactionId;
  final Money amount;
  final int paidFromAccountId;
  final int expenseAccountId;
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

  final int transactionId;
  final Money amount;
  final int receiveAccountId;
  final int incomeAccountId;
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

  final int transactionId;
  final Money amount;
  final int fromAccountId;
  final int toAccountId;
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

  final int transactionId;
  final Money amount;
  final int receivableAccountId;
  final int paidFromAccountId;
  final int expenseCategoryId;
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

  final int transactionId;
  final Money amount;
  final int refundToAccountId;
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

  final int transactionId;
  final Money amount;
  final int receivableAccountId;
  final int receiveAccountId;
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

  final int transactionId;
  final Money actualReceivedAmount;
  final int receivableAccountId;
  final int receiveAccountId;
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

  final int transactionId;
  final Money amount;
  final int liabilityAccountId;
  final int receiveAccountId;
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

  final int transactionId;
  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final int liabilityAccountId;
  final int paidFromAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class DeleteTransactionCommand {
  const DeleteTransactionCommand({required this.transactionId});

  final int transactionId;
}

class UpdateTransactionMetadataCommand {
  const UpdateTransactionMetadataCommand({
    required this.transactionId,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final int transactionId;

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

  final int transactionId;
  final DateTime? occurredAt;
  final int? settlementAccountId;
  final int? reimbursementAccountId;
}

class UpdateTransactionOwnershipCommand {
  const UpdateTransactionOwnershipCommand({
    required this.transactionId,
    required this.ownership,
  });

  final int transactionId;
  final TransactionOwnership ownership;
}

/// transaction_service 的所有写入命令统一返回此结果。
/// 内部 ledger 的 PostTransactionResult 不对外暴露；service 实现把它映射成本类型。
class CreatedTransactionResult {
  const CreatedTransactionResult({
    required this.transactionId,
    required this.rootTransactionId,
  });

  final int transactionId;
  final int rootTransactionId;
}
