import 'transaction_ownership.dart';
import 'ledger_enum.dart';
import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../service/ledger_rule.dart';

/// 入账凭证:对一笔交易"长什么样"的完整描述。
///
/// 由 PostingAppService 内部的 receipt 构造方法从 user command 派生,经
/// [validate] 校验后由 PostingAppService 落库。不携带 mutation 元数据
/// (mutationKind / mutationPreviousTransactionId 等) — 这些字段在
/// PostingAppService 的 replace / cancel 路径上从 original 派生注入,
/// 构造路径永远只造"独立合法"的蓝字凭证。
class PostReceipt {
  const PostReceipt({
    required this.businessPurpose,
    required this.occurredAt,
    required this.primaryAmount,
    required this.details,
    required this.entries,
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

  /// 凭证级合法性自校验。
  ///
  /// - 蓝字路径(create / correction-blue):金额一律 > 0
  /// - 红字路径(reversal):金额一律 < 0,由 caller 传 `allowNegativeAmounts: true`
  ///
  /// 返回 `null` 表示合法。
  Failure? validate({bool allowNegativeAmounts = false}) {
    if (details.isEmpty) {
      return const Failure(
        code: 'details_required',
        message: 'A transaction must have at least one detail.',
      );
    }
    if (entries.length < 2) {
      return const Failure(
        code: 'entries_required',
        message: 'A transaction must have at least two entries.',
      );
    }
    if ((!allowNegativeAmounts && primaryAmount.minorUnits <= 0) ||
        (allowNegativeAmounts && primaryAmount.minorUnits == 0)) {
      return const Failure(
        code: 'primary_amount_not_positive',
        message: 'Primary amount has an invalid sign.',
      );
    }
    for (final detail in details) {
      if (!_amountSignIsValid(
        amountMinor: detail.amount.minorUnits,
        expectsNegative: allowNegativeAmounts,
      )) {
        return Failure(
          code: 'detail_amount_sign_invalid',
          message:
              'Detail amount must be '
              '${allowNegativeAmounts ? 'negative' : 'positive'}.',
        );
      }
      if (!detailTypeAllowedForPurpose(
        detailType: detail.type,
        businessPurpose: businessPurpose,
      )) {
        return Failure(
          code: 'detail_type_not_allowed',
          message:
              '${detail.type.name} is not allowed for '
              '${businessPurpose.name}.',
        );
      }
    }
    for (final entry in entries) {
      if (!_amountSignIsValid(
        amountMinor: entry.amount.minorUnits,
        expectsNegative: allowNegativeAmounts,
      )) {
        return Failure(
          code: 'entry_amount_sign_invalid',
          message:
              'Entry amount must be '
              '${allowNegativeAmounts ? 'negative' : 'positive'}.',
        );
      }
    }
    if (!entriesAreBalanced(entries)) {
      return const Failure(
        code: 'entries_not_balanced',
        message: 'Debit and credit entries must be balanced.',
      );
    }
    return null;
  }

  static bool _amountSignIsValid({
    required int amountMinor,
    required bool expectsNegative,
  }) {
    return expectsNegative ? amountMinor < 0 : amountMinor > 0;
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
