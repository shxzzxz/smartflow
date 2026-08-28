import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../service/posting/posting_rule.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/ledger_violation_reason.dart';
import '../valobj/account_amount_allocation.dart';
import '../valobj/transaction_ownership.dart';
import 'entry.dart';
import 'transaction_line.dart';

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
    this.lines = const [],
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
  bool isExcludedFromStats;
  bool isExcludedFromBudget;
  final SourceKind sourceKind;
  TransactionOwnership? ownership;
  final List<TransactionLine> lines;
  final List<Entry> entries;

  Set<String> get accountIds => entries.map((entry) => entry.accountId).toSet();

  Iterable<TransactionLine> linesOf(TransactionRole role) =>
      lines.where((line) => line.role == role);

  /// Reads all account-bearing lines for a role without collapsing multiple
  /// allocations into the first line.
  ///
  /// Account-bearing roles are required to carry an account ID. Persisted
  /// malformed lines are rejected consistently instead of failing with a
  /// nullable force-unwrap in each caller.
  List<AccountAmountAllocation> accountAllocationsOf(TransactionRole role) {
    return [
      for (final line in linesOf(role))
        AccountAmountAllocation(
          accountId:
              line.accountId ??
              LedgerViolationReason.lineAccountExpectationViolated
                  .throwException(
                    message: '${role.name} allocation is missing an account.',
                  ),
          amount: line.amount,
        ),
    ];
  }

  TransactionLine? lineOf(TransactionRole role) => linesOf(role).firstOrNull;

  /// Returns the sum of all lines for [role], or null when the role is absent.
  ///
  /// A role may be represented by multiple allocations (for example, a
  /// reimbursement can be received into several settlement accounts), so
  /// callers must not use only the first matching line as the role amount.
  Money? amountOf(TransactionRole role) {
    final matchingLines = linesOf(role);
    if (matchingLines.isEmpty) return null;
    return matchingLines.fold<Money>(
      Money.zero(),
      (total, line) => total + line.amount,
    );
  }

  String? accountOf(TransactionRole role) => lineOf(role)?.accountId;

  bool hasSameAccountingExpressionAs(Transaction other) {
    return businessPurpose == other.businessPurpose &&
        primaryAmount == other.primaryAmount &&
        parentTransactionId == other.parentTransactionId &&
        sameLines(lines, other.lines) &&
        sameEntries(entries, other.entries);
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

  void validateSelf() {
    if (lines.isEmpty) {
      LedgerViolationReason.linesRequired.throwException(
        message: 'A transaction must have at least one line.',
      );
    }
    if (entries.length < 2) {
      LedgerViolationReason.entriesRequired.throwException(
        message: 'A transaction must have at least two entries.',
      );
    }
    if (primaryAmount.minorUnits < 0 ||
        (primaryAmount.minorUnits == 0 &&
            !primaryAmountAllowsZero(businessPurpose))) {
      LedgerViolationReason.primaryAmountNotPositive.throwException(
        message: 'Primary amount has an invalid sign.',
      );
    }
    for (final line in lines) {
      _validateLine(line);
    }
    for (final entry in entries) {
      if (entry.amount.minorUnits <= 0) {
        LedgerViolationReason.entryAmountSignInvalid.throwException(
          message: 'Entry amount must be positive.',
        );
      }
    }
    if (!entriesAreBalanced(entries)) {
      LedgerViolationReason.entriesNotBalanced.throwException(
        message: 'Debit and credit entries must be balanced.',
      );
    }
  }

  void _validateLine(TransactionLine line) {
    if (!roleAllowedForPurpose(
      role: line.role,
      businessPurpose: businessPurpose,
    )) {
      LedgerViolationReason.lineRoleNotAllowed.throwException(
        message:
            '${line.role.name} is not allowed for ${businessPurpose.name}.',
      );
    }
    if (roleCarriesAccount(line.role) != (line.accountId != null)) {
      LedgerViolationReason.lineAccountExpectationViolated.throwException(
        message:
            '${line.role.name} must '
            '${roleCarriesAccount(line.role) ? 'carry' : 'omit'} an account.',
      );
    }
    // 结算腿允许为零:结束报销可以一分未收,还款可以只付利息。
    final signValid =
        roleAmountIsSigned(line.role)
            ? line.amount.minorUnits != 0
            : line.amount.minorUnits >= 0;
    if (!signValid) {
      LedgerViolationReason.lineAmountSignInvalid.throwException(
        message: '${line.role.name} amount has an invalid sign.',
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
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    SourceKind? sourceKind,
    TransactionOwnership? ownership,
    List<TransactionLine>? lines,
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
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
      sourceKind: sourceKind ?? this.sourceKind,
      ownership: ownership ?? this.ownership,
      lines:
          lines ??
          [
            for (final line in this.lines)
              TransactionLine(
                id: line.id,
                transactionId:
                    line.transactionId == this.id ? nextId : line.transactionId,
                lineNo: line.lineNo,
                role: line.role,
                accountId: line.accountId,
                amount: line.amount,
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

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

extension BusinessPurposeBehavior on BusinessPurpose {
  bool get isExpense =>
      this == BusinessPurpose.dailyExpense ||
      this == BusinessPurpose.reimbursementAdvance ||
      this == BusinessPurpose.badDebt;

  bool get isIncome =>
      this == BusinessPurpose.dailyIncome || this == BusinessPurpose.debtRelief;

  bool get isIncomeOrExpense => isIncome || isExpense;
}
