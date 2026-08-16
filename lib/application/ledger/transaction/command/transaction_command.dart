import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';

class CreateExpenseCommand {
  const CreateExpenseCommand({
    required this.amount,
    required this.paidFromAccountId,
    required this.expenseAccountId,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
    this.tagIds = const {},
  });

  final Money amount;
  final String paidFromAccountId;
  final String expenseAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;

  /// 交易携带的标签 ID；标签挂在顶层交易上，随入账一并写入。
  final Set<String> tagIds;
}

class CreateIncomeCommand {
  const CreateIncomeCommand({
    required this.amount,
    required this.receiveAccountId,
    required this.incomeAccountId,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
    this.tagIds = const {},
  });

  final Money amount;
  final String receiveAccountId;
  final String incomeAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;
  final Set<String> tagIds;
}

class CreateTransferCommand {
  const CreateTransferCommand({
    required this.amount,
    required this.fromAccountId,
    required this.toAccountId,
    required this.occurredAt,
    this.postedAt,
    this.feeAmount,
    this.counterpartyName,
    this.note,
    this.sourceKind = SourceKind.manual,
    this.tagIds = const {},
  });

  final Money amount;
  final String fromAccountId;
  final String toAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final Money? feeAmount;
  final String? counterpartyName;
  final String? note;
  final SourceKind sourceKind;
  final Set<String> tagIds;
}

class CreateRefundCommand {
  const CreateRefundCommand({
    required this.amount,
    required this.parentTransactionId,
    required this.refundToAccountId,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyName,
    this.note,
  });

  final Money amount;
  final String parentTransactionId;
  final String refundToAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
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
    this.postedAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
    this.tagIds = const {},
  });

  final Money amount;
  final String receivableAccountId;
  final String paidFromAccountId;
  final String expenseCategoryId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;
  final Set<String> tagIds;
}

class CreateReimbursementReceiptCommand {
  const CreateReimbursementReceiptCommand({
    required this.amount,
    required this.advanceTransactionId,
    required this.receivableAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyName,
    this.note,
  });

  final Money amount;
  final String advanceTransactionId;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
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
    this.postedAt,
    this.counterpartyName,
    this.note,
  });

  final Money actualReceivedAmount;
  final String advanceTransactionId;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyName;
  final String? note;
}

class CreateRepaymentCommand {
  const CreateRepaymentCommand({
    required this.principal,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.postedAt,
    this.interest,
    this.fee,
    this.discount,
    this.counterpartyName,
    this.note,
    this.ownership,
    this.sourceKind = SourceKind.manual,
    this.tagIds = const {},
  });

  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final String liabilityAccountId;
  final String paidFromAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyName;
  final String? note;
  final TransactionOwnership? ownership;
  final SourceKind sourceKind;

  /// 交易携带的标签 ID；随入账一并写入。
  final Set<String> tagIds;
}

class CreateBorrowingCommand {
  const CreateBorrowingCommand({
    required this.amount,
    required this.liabilityAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyName,
    this.note,
    this.ownership,
    this.sourceKind = SourceKind.manual,
    this.tagIds = const {},
  });

  final Money amount;
  final String liabilityAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyName;
  final String? note;
  final TransactionOwnership? ownership;
  final SourceKind sourceKind;
  final Set<String> tagIds;
}

class CreateOpeningBalanceCommand {
  const CreateOpeningBalanceCommand({
    required this.accountId,
    required this.amount,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyName,
    this.note,
    this.sourceKind = SourceKind.manual,
  });

  final String accountId;
  final Money amount;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyName;
  final String? note;
  final SourceKind sourceKind;
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

class EditExpenseCommand {
  const EditExpenseCommand({
    required this.transactionId,
    this.amount,
    this.paidFromAccountId,
    this.expenseAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
    this.tagIds,
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

  /// `null` 表示不改标签；非空集合表示用该集合整体替换交易标签。
  final Set<String>? tagIds;
}

class EditIncomeCommand {
  const EditIncomeCommand({
    required this.transactionId,
    this.amount,
    this.receiveAccountId,
    this.incomeAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.tagIds,
  });

  final String transactionId;
  final Money? amount;
  final String? receiveAccountId;
  final String? incomeAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
  final bool? isExcludedFromStats;

  /// `null` 表示不改标签；非空集合表示用该集合整体替换交易标签。
  final Set<String>? tagIds;
}

class EditTransferCommand {
  const EditTransferCommand({
    required this.transactionId,
    this.amount,
    this.fromAccountId,
    this.toAccountId,
    this.occurredAt,
    this.feeAmount,
    this.counterpartyName,
    this.note,
    this.tagIds,
  });

  final String transactionId;
  final Money? amount;
  final String? fromAccountId;
  final String? toAccountId;
  final DateTime? occurredAt;
  final Money? feeAmount;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;

  /// `null` 表示不改标签；非空集合表示用该集合整体替换交易标签。
  final Set<String>? tagIds;
}

class EditReimbursementAdvanceCommand {
  const EditReimbursementAdvanceCommand({
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
    this.tagIds,
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

  /// `null` 表示不改标签；非空集合表示用该集合整体替换交易标签。
  final Set<String>? tagIds;
}

class EditRefundCommand {
  const EditRefundCommand({
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

class EditReimbursementReceiptCommand {
  const EditReimbursementReceiptCommand({
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

class EditReimbursementCloseCommand {
  const EditReimbursementCloseCommand({
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

class EditBorrowingCommand {
  const EditBorrowingCommand({
    required this.transactionId,
    this.amount,
    this.liabilityAccountId,
    this.receiveAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
    this.tagIds,
  });

  final String transactionId;
  final Money? amount;
  final String? liabilityAccountId;
  final String? receiveAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;

  /// `null` 表示不改标签；非空集合表示用该集合整体替换交易标签。
  final Set<String>? tagIds;
}

class EditRepaymentCommand {
  const EditRepaymentCommand({
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
    this.tagIds,
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

  /// `null` 表示不改标签；非空集合表示用该集合整体替换交易标签。
  final Set<String>? tagIds;
}

class DeleteTransactionCommand {
  const DeleteTransactionCommand({required this.transactionId});

  final String transactionId;
}

/// 按条件批量清理交易组。条件语义与 `TransactionCleanupQuery` 一致。
class CleanupTransactionsCommand {
  const CleanupTransactionsCommand({
    this.categoryIds,
    this.accountIds,
    this.occurredFrom,
    this.occurredUntil,
  });

  final Set<String>? categoryIds;
  final Set<String>? accountIds;
  final DateTime? occurredFrom;
  final DateTime? occurredUntil;
}

class TransactionCleanupResult {
  const TransactionCleanupResult({
    required this.deletedGroupCount,
    required this.skippedGroupCount,
  });

  /// 已删除的交易组数量。
  final int deletedGroupCount;

  /// 因带业务归属而跳过的交易组数量。
  final int skippedGroupCount;
}

class UpdateTransactionBasicInfoCommand {
  const UpdateTransactionBasicInfoCommand({
    required this.transactionId,
    this.occurredAt,
    this.postedAt,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final DateTime? occurredAt;
  final DateTime? postedAt;
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
  const PostedTransactionResult({required this.transactionId});

  final String transactionId;
}
