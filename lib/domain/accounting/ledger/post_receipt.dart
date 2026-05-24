import '../../../core/money/money.dart';
import '../entities/transaction_ownership.dart';
import '../enums/accounting_enums.dart';

/// 入账凭证:对一笔交易"长什么样"的完整描述。
///
/// 由 ReceiptBuilder 从 user command 派生,经 Poster 校验后落库。
/// 不携带 mutation 元数据(mutationKind / mutationPreviousTransactionId 等) —
/// 这些字段在 [Poster.replace] / [Poster.cancel] 内部从 original 派生注入,
/// builder 永远只造"独立合法"的蓝字凭证。
class PostReceipt {
  const PostReceipt({
    required this.businessPurpose,
    required this.occurredAt,
    required this.primaryAmount,
    required this.details,
    required this.entries,
    this.currencyCode = Money.defaultCurrency,
    this.rootTransactionId,
    this.parentTransactionId,
    this.reimbursementExpenseAccountId,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
    this.ownership,
  });

  final BusinessPurpose businessPurpose;
  final DateTime occurredAt;
  final String currencyCode;
  final Money primaryAmount;
  final List<ReceiptDetail> details;
  final List<ReceiptEntry> entries;
  final int? rootTransactionId;
  final int? parentTransactionId;
  final int? reimbursementExpenseAccountId;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;
  final TransactionOwnership? ownership;

  PostReceipt copyWith({
    BusinessPurpose? businessPurpose,
    DateTime? occurredAt,
    String? currencyCode,
    Money? primaryAmount,
    List<ReceiptDetail>? details,
    List<ReceiptEntry>? entries,
    int? rootTransactionId,
    int? parentTransactionId,
    int? reimbursementExpenseAccountId,
    String? counterpartyName,
    String? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    SourceKind? sourceKind,
    TransactionOwnership? ownership,
  }) {
    return PostReceipt(
      businessPurpose: businessPurpose ?? this.businessPurpose,
      occurredAt: occurredAt ?? this.occurredAt,
      currencyCode: currencyCode ?? this.currencyCode,
      primaryAmount: primaryAmount ?? this.primaryAmount,
      details: details ?? this.details,
      entries: entries ?? this.entries,
      rootTransactionId: rootTransactionId ?? this.rootTransactionId,
      parentTransactionId: parentTransactionId ?? this.parentTransactionId,
      reimbursementExpenseAccountId:
          reimbursementExpenseAccountId ?? this.reimbursementExpenseAccountId,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      note: note ?? this.note,
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
      sourceKind: sourceKind ?? this.sourceKind,
      ownership: ownership ?? this.ownership,
    );
  }
}

class ReceiptDetail {
  const ReceiptDetail({
    required this.lineNo,
    required this.type,
    required this.amount,
  });

  final int lineNo;
  final TransactionDetailType type;
  final Money amount;
}

class ReceiptEntry {
  const ReceiptEntry({
    required this.accountId,
    required this.direction,
    required this.amount,
  });

  final int accountId;
  final EntryDirection direction;
  final Money amount;
}

class PostReceiptResult {
  const PostReceiptResult({
    required this.transactionId,
    required this.rootTransactionId,
  });

  final int transactionId;
  final int rootTransactionId;
}

/// `updateTransactionBasics` 用于改交易 settlement / reimbursement account
/// 的指令。
class EntryAccountReassignment {
  const EntryAccountReassignment({
    required this.fromAccountId,
    required this.toAccountId,
    this.transactionId,
    this.rootTransactionId,
  }) : assert(
         (transactionId == null) != (rootTransactionId == null),
         'Exactly one reassignment scope must be provided.',
       );

  final int fromAccountId;
  final int toAccountId;
  final int? transactionId;
  final int? rootTransactionId;
}
