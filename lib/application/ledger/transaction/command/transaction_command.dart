import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
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
  });

  final Money amount;
  final String receiveAccountId;
  final String incomeAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
}

class CreateTransferCommand {
  const CreateTransferCommand({
    required this.amount,
    required this.fromAccountId,
    required this.toAccountId,
    required this.occurredAt,
    this.feeAmount,
    this.counterpartyName,
    this.note,
  });

  final Money amount;
  final String fromAccountId;
  final String toAccountId;
  final DateTime occurredAt;
  final Money? feeAmount;
  final String? counterpartyName;
  final String? note;
}

class CreateRefundCommand {
  const CreateRefundCommand({
    required this.amount,
    required this.parentTransactionId,
    required this.refundToAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final Money amount;
  final String parentTransactionId;
  final String refundToAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
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
  });

  final Money amount;
  final String advanceTransactionId;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
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
  });

  final Money actualReceivedAmount;
  final String advanceTransactionId;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
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
  });

  final Money amount;
  final String liabilityAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final TransactionOwnership? ownership;
}

class CreateOpeningBalanceCommand {
  const CreateOpeningBalanceCommand({
    required this.accountId,
    required this.amount,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String accountId;
  final Money amount;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
}

class AdjustBalanceCommand {
  const AdjustBalanceCommand({
    required this.accountId,
    required this.targetBalance,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String accountId;
  final Money targetBalance;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
}

class CorrectExpenseCommand {
  const CorrectExpenseCommand({
    required this.transactionId,
    this.amount,
    this.paidFromAccountId,
    this.expenseAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money? amount;
  final String? paidFromAccountId;
  final String? expenseAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class CorrectIncomeCommand {
  const CorrectIncomeCommand({
    required this.transactionId,
    this.amount,
    this.receiveAccountId,
    this.incomeAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
  });

  final String transactionId;
  final Money? amount;
  final String? receiveAccountId;
  final String? incomeAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
  final bool? isExcludedFromStats;
}

class CorrectTransferCommand {
  const CorrectTransferCommand({
    required this.transactionId,
    this.amount,
    this.fromAccountId,
    this.toAccountId,
    this.occurredAt,
    this.feeAmount,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final Money? amount;
  final String? fromAccountId;
  final String? toAccountId;
  final DateTime? occurredAt;
  final Money? feeAmount;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
}

class CorrectReimbursementAdvanceCommand {
  const CorrectReimbursementAdvanceCommand({
    required this.transactionId,
    this.amount,
    this.receivableAccountId,
    this.paidFromAccountId,
    this.expenseCategoryId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final Money? amount;
  final String? receivableAccountId;
  final String? paidFromAccountId;
  final String? expenseCategoryId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class CorrectRefundCommand {
  const CorrectRefundCommand({
    required this.transactionId,
    this.amount,
    this.refundToAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final Money? amount;
  final String? refundToAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
}

class CorrectReimbursementReceiptCommand {
  const CorrectReimbursementReceiptCommand({
    required this.transactionId,
    this.amount,
    this.receivableAccountId,
    this.receiveAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final Money? amount;
  final String? receivableAccountId;
  final String? receiveAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
}

class CorrectReimbursementCloseCommand {
  const CorrectReimbursementCloseCommand({
    required this.transactionId,
    this.actualReceivedAmount,
    this.receivableAccountId,
    this.receiveAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final Money? actualReceivedAmount;
  final String? receivableAccountId;
  final String? receiveAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
}

class CorrectBorrowingCommand {
  const CorrectBorrowingCommand({
    required this.transactionId,
    this.amount,
    this.liabilityAccountId,
    this.receiveAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final Money? amount;
  final String? liabilityAccountId;
  final String? receiveAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
}

class CorrectRepaymentCommand {
  const CorrectRepaymentCommand({
    required this.transactionId,
    this.principal,
    this.liabilityAccountId,
    this.paidFromAccountId,
    this.occurredAt,
    this.interest,
    this.fee,
    this.discount,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final Money? principal;
  final Patch<Money?>? interest;
  final Patch<Money?>? fee;
  final Patch<Money?>? discount;
  final String? liabilityAccountId;
  final String? paidFromAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
}

class DeleteTransactionCommand {
  const DeleteTransactionCommand({required this.transactionId});

  final String transactionId;
}

class UpdateTransactionBasicInfoCommand {
  const UpdateTransactionBasicInfoCommand({
    required this.transactionId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
}

class UpdateTransactionReportingFlagCommand {
  const UpdateTransactionReportingFlagCommand({
    required this.transactionId,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class UpdateTransactionOwnershipCommand {
  const UpdateTransactionOwnershipCommand({
    required this.transactionId,
    required this.ownership,
  });

  final String transactionId;
  final TransactionOwnership ownership;
}

/// transaction_service 的所有入账写入命令统一返回此结果。
class PostedTransactionResult {
  const PostedTransactionResult({
    required this.transactionId,
    required this.rootTransactionId,
  });

  final String transactionId;
  final String rootTransactionId;
}
