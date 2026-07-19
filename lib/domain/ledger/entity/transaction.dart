import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../service/posting/posting_rule.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/ledger_violation_reason.dart';
import '../valobj/transaction_ownership.dart';
import 'entry.dart';
import 'transaction_detail_record.dart';

class Transaction {
  Transaction({
    required this.id,
    required this.businessPurpose,
    required this.occurredAt,
    DateTime? postedAt,
    required this.primaryAmount,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    required this.sourceKind,
    this.ownership,
    this.counterpartyName,
    this.note,
    this.parentTransactionId,
    this.reimbursementExpenseAccountId,
    this.details = const [],
    this.entries = const [],
  }) : postedAt = postedAt ?? occurredAt;

  final String id;
  final BusinessPurpose businessPurpose;
  DateTime occurredAt;
  DateTime postedAt;
  final Money primaryAmount;
  String? counterpartyName;
  String? note;
  final String? parentTransactionId;
  final String? reimbursementExpenseAccountId;
  bool isExcludedFromStats;
  bool isExcludedFromBudget;
  final SourceKind sourceKind;
  TransactionOwnership? ownership;
  final List<TransactionDetailRecord> details;
  final List<Entry> entries;

  Set<String> get accountIds => entries.map((entry) => entry.accountId).toSet();

  bool hasSameAccountingExpressionAs(Transaction other) {
    if (businessPurpose != other.businessPurpose ||
        primaryAmount != other.primaryAmount ||
        parentTransactionId != other.parentTransactionId ||
        details.length != other.details.length ||
        entries.length != other.entries.length) {
      return false;
    }
    for (var index = 0; index < details.length; index++) {
      final left = details[index];
      final right = other.details[index];
      if (left.type != right.type || left.amount != right.amount) return false;
    }
    for (var index = 0; index < entries.length; index++) {
      final left = entries[index];
      final right = other.entries[index];
      if (left.accountId != right.accountId ||
          left.direction != right.direction ||
          left.amount != right.amount) {
        return false;
      }
    }
    return true;
  }

  /// 基础信息(occurredAt / postedAt / settlement / reimbursement account)更新路径。
  void assertCanBeBasicsUpdated() {}

  void updateBasicInfo({
    DateTime? occurredAt,
    DateTime? postedAt,
    Patch<String?>? counterpartyName,
    Patch<String?>? note,
  }) {
    if (occurredAt != null) this.occurredAt = occurredAt;
    if (postedAt != null) this.postedAt = postedAt;
    if (counterpartyName != null) {
      this.counterpartyName = switch (counterpartyName) {
        PatchSet<String?>(:final value) => _blankToNull(value),
        PatchClear<String?>() => null,
      };
    }
    if (note != null) {
      this.note = switch (note) {
        PatchSet<String?>(:final value) => _blankToNull(value),
        PatchClear<String?>() => null,
      };
    }
  }

  void updateReportingFlags({
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    required BusinessPurpose parentPurpose,
  }) {
    if (!parentPurpose.isIncomeOrExpense) {
      this.isExcludedFromStats = false;
      this.isExcludedFromBudget = false;
      return;
    }
    if (isExcludedFromStats != null) {
      this.isExcludedFromStats = isExcludedFromStats;
    }
    if (parentPurpose.isExpense) {
      if (isExcludedFromBudget != null) {
        this.isExcludedFromBudget = isExcludedFromBudget;
      }
    } else {
      this.isExcludedFromBudget = false;
    }
  }

  void updateOwnership(TransactionOwnership ownership) {
    this.ownership = ownership;
  }

  void validateSelf({bool allowNegativeAmounts = false}) {
    if (details.isEmpty) {
      LedgerViolationReason.detailsRequired.throwException(
        message: 'A transaction must have at least one detail.',
      );
    }
    if (entries.length < 2) {
      LedgerViolationReason.entriesRequired.throwException(
        message: 'A transaction must have at least two entries.',
      );
    }
    if ((!allowNegativeAmounts && primaryAmount.minorUnits <= 0) ||
        (allowNegativeAmounts && primaryAmount.minorUnits == 0)) {
      LedgerViolationReason.primaryAmountNotPositive.throwException(
        message: 'Primary amount has an invalid sign.',
      );
    }
    for (final detail in details) {
      final isZeroRepaymentPrincipal =
          businessPurpose == BusinessPurpose.debtRepayment &&
          detail.type == TransactionDetailType.repaymentPrincipal &&
          detail.amount.minorUnits == 0;
      if (!isZeroRepaymentPrincipal &&
          !_amountSignIsValid(
            amountMinor: detail.amount.minorUnits,
            expectsNegative: allowNegativeAmounts,
          )) {
        LedgerViolationReason.detailAmountSignInvalid.throwException(
          message:
              'Detail amount must be '
              '${allowNegativeAmounts ? 'negative' : 'positive'}.',
        );
      }
      if (!detailTypeAllowedForPurpose(
        detailType: detail.type,
        businessPurpose: businessPurpose,
      )) {
        LedgerViolationReason.detailTypeNotAllowed.throwException(
          message:
              '${detail.type.name} is not allowed for '
              '${businessPurpose.name}.',
        );
      }
    }
    final hasZeroRepaymentPrincipal =
        businessPurpose == BusinessPurpose.debtRepayment &&
        details.any(
          (detail) =>
              detail.type == TransactionDetailType.repaymentPrincipal &&
              detail.amount.minorUnits == 0,
        );
    for (final entry in entries) {
      final isZeroRepaymentEntry =
          hasZeroRepaymentPrincipal &&
          entry.direction == EntryDirection.debit &&
          entry.amount.minorUnits == 0;
      if (!isZeroRepaymentEntry &&
          !_amountSignIsValid(
            amountMinor: entry.amount.minorUnits,
            expectsNegative: allowNegativeAmounts,
          )) {
        LedgerViolationReason.entryAmountSignInvalid.throwException(
          message:
              'Entry amount must be '
              '${allowNegativeAmounts ? 'negative' : 'positive'}.',
        );
      }
    }
    if (!entriesAreBalanced(entries)) {
      LedgerViolationReason.entriesNotBalanced.throwException(
        message: 'Debit and credit entries must be balanced.',
      );
    }
  }

  /// 更新元数据(note 三态 + 排除统计 / 排除预算)。
  /// note 用 [Patch] 表达三态;两个 bool 用 `null` 表示不改。
  Transaction updatedMetadata({
    Patch<String>? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
  }) {
    return copyWith(
      notePatch: note,
      isExcludedFromStats: isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget,
    );
  }

  Transaction updatedOwnership(TransactionOwnership ownership) {
    return copyWith(ownership: ownership);
  }

  Transaction withOccurredAt(DateTime occurredAt) {
    return copyWith(occurredAt: occurredAt);
  }

  Transaction copyWith({
    String? id,
    BusinessPurpose? businessPurpose,
    DateTime? occurredAt,
    DateTime? postedAt,
    Money? primaryAmount,
    String? counterpartyName,
    Patch<String>? notePatch,
    String? parentTransactionId,
    String? reimbursementExpenseAccountId,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    SourceKind? sourceKind,
    TransactionOwnership? ownership,
    List<TransactionDetailRecord>? details,
    List<Entry>? entries,
  }) {
    final nextId = id ?? this.id;
    return Transaction(
      id: nextId,
      businessPurpose: businessPurpose ?? this.businessPurpose,
      occurredAt: occurredAt ?? this.occurredAt,
      postedAt: postedAt ?? this.postedAt,
      primaryAmount: primaryAmount ?? this.primaryAmount,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      note: switch (notePatch) {
        null => note,
        PatchSet<String>(:final value) => _blankToNull(value),
        PatchClear<String>() => null,
      },
      parentTransactionId: parentTransactionId ?? this.parentTransactionId,
      reimbursementExpenseAccountId:
          reimbursementExpenseAccountId ?? this.reimbursementExpenseAccountId,
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
      sourceKind: sourceKind ?? this.sourceKind,
      ownership: ownership ?? this.ownership,
      details:
          details ??
          [
            for (final detail in this.details)
              TransactionDetailRecord(
                id: detail.id,
                transactionId:
                    detail.transactionId == this.id
                        ? nextId
                        : detail.transactionId,
                lineNo: detail.lineNo,
                type: detail.type,
                amount: detail.amount,
              ),
          ],
      entries:
          entries ??
          [
            for (final entry in this.entries)
              Entry(
                id: entry.id,
                transactionId:
                    entry.transactionId == this.id
                        ? nextId
                        : entry.transactionId,
                accountId: entry.accountId,
                direction: entry.direction,
                amount: entry.amount,
              ),
          ],
    );
  }

  static bool _amountSignIsValid({
    required int amountMinor,
    required bool expectsNegative,
  }) {
    return expectsNegative ? amountMinor < 0 : amountMinor > 0;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

extension BusinessPurposeBehavior on BusinessPurpose {
  bool get isExpense =>
      this == BusinessPurpose.dailyExpense ||
      this == BusinessPurpose.reimbursementAdvance;

  bool get isIncome => this == BusinessPurpose.dailyIncome;

  bool get isIncomeOrExpense => isIncome || isExpense;
}
