import '../../../core/money/money.dart';
import '../valobj/account_amount_allocation.dart';
import '../valobj/ledger_enum.dart';
import 'transaction.dart';

class TransactionGroup {
  const TransactionGroup({
    required this.parentTransaction,
    required this.childTransactions,
  });

  final Transaction parentTransaction;
  final List<Transaction> childTransactions;

  Iterable<Transaction> get transactions sync* {
    yield parentTransaction;
    yield* childTransactions;
  }

  Transaction? findTransaction(String transactionId) {
    for (final transaction in transactions) {
      if (transaction.id == transactionId) return transaction;
    }
    return null;
  }

  Money refundedTotal({String? excludingTransactionId}) {
    return _refundSummary(
          excludingTransactionId: excludingTransactionId,
        )?.refundedTotal ??
        Money.zero();
  }

  /// 退款只减少垫付应收中属于“垫付”的部分；自承担退款冲减支出。
  ///
  /// v47 的旧表示由数据迁移改写，这里只读取规范的 receivable 分项。
  Money advanceRefundedTotal({String? excludingTransactionId}) {
    return childTransactions
        .where(
          (child) =>
              child.businessPurpose == BusinessPurpose.refund &&
              child.id != excludingTransactionId,
        )
        .fold(
          Money.zero(),
          (total, child) =>
              total +
              (child.amountOf(TransactionRole.receivable) ?? Money.zero()),
        );
  }

  Money advanceCollectedTotal({String? excludingTransactionId}) {
    return _advanceSummary(
          excludingTransactionId: excludingTransactionId,
        )?.receivedAmount ??
        Money.zero();
  }

  /// The only calculation source for refund facts in a transaction group.
  RefundSummary? get refundSummary => _refundSummary();

  /// The only calculation source for advance facts in a transaction group.
  AdvanceSummary? get advanceSummary => _advanceSummary();

  Money advanceOutstanding() {
    return advanceSummary?.outstanding ?? Money.zero();
  }

  /// 排除某笔子交易后的待核销额。
  ///
  /// 重建该子交易时用它推导待收回与结清差额,避免把子交易自己的派生分项读回来
  /// 当输入。
  Money advanceOutstandingExcluding(String childTransactionId) {
    return _advanceSummary(
          excludingTransactionId: childTransactionId,
        )?.outstanding ??
        Money.zero();
  }

  List<AccountAmountAllocation> get categoryAllocations {
    return refundSummary?.originalCategoryAllocations ?? const [];
  }

  List<AccountAmountAllocation> refundCategoryAllocations(Transaction refund) {
    final role = parentTransaction.businessPurpose == BusinessPurpose.advance
        ? TransactionRole.advanceExpenseCategory
        : TransactionRole.refundOffset;
    return refund.accountAllocationsOf(role);
  }

  List<AccountAmountAllocation> remainingRefundableCategoryAllocations({
    String? excludingTransactionId,
  }) {
    return _refundSummary(
          excludingTransactionId: excludingTransactionId,
        )?.remainingCategoryAllocations ??
        const [];
  }

  bool allocationsFitRefundableCategories(
    Iterable<AccountAmountAllocation> allocations, {
    String? excludingTransactionId,
  }) {
    return allocationsFitAvailable(
      requested: allocations,
      available: remainingRefundableCategoryAllocations(
        excludingTransactionId: excludingTransactionId,
      ),
    );
  }

  RefundSummary? _refundSummary({String? excludingTransactionId}) {
    final role = switch (parentTransaction.businessPurpose) {
      BusinessPurpose.dailyExpense => TransactionRole.category,
      BusinessPurpose.advance => TransactionRole.advanceExpenseCategory,
      _ => null,
    };
    if (role == null) return null;
    final original = parentTransaction.accountAllocationsOf(role);
    final refunded = [
      for (final child in childTransactions.where(
        (child) =>
            child.businessPurpose == BusinessPurpose.refund &&
            child.id != excludingTransactionId,
      ))
        ...refundCategoryAllocations(child),
    ];
    return RefundSummary(
      refundedTotal: _sumSettlementIn(
        purposes: const {BusinessPurpose.refund},
        excludingTransactionId: excludingTransactionId,
      ),
      originalCategoryAllocations: original,
      refundedCategoryAllocations: refunded,
    );
  }

  AdvanceSummary? _advanceSummary({String? excludingTransactionId}) {
    if (parentTransaction.businessPurpose != BusinessPurpose.advance) {
      return null;
    }
    final refunded = _sumSettlementIn(
      purposes: const {BusinessPurpose.refund},
      excludingTransactionId: excludingTransactionId,
    );
    final advanceRefunded = advanceRefundedTotal(
      excludingTransactionId: excludingTransactionId,
    );
    final received = _sumSettlementIn(
      purposes: const {
        BusinessPurpose.advanceCollection,
        BusinessPurpose.advanceSettlement,
      },
      excludingTransactionId: excludingTransactionId,
    );
    final gap = childTransactions
        .where(
          (child) =>
              child.businessPurpose == BusinessPurpose.advanceSettlement &&
              child.id != excludingTransactionId,
        )
        .fold(Money.zero(), (total, child) {
          return total +
              (child.amountOf(TransactionRole.advanceCompensationIncome) ??
                  Money.zero()) -
              (child.amountOf(TransactionRole.advanceSelfBorne) ??
                  Money.zero()) -
              (child.amountOf(TransactionRole.advanceBadDebtExpense) ??
                  Money.zero());
        });
    final closed = childTransactions.any(
      (child) =>
          child.id != excludingTransactionId &&
          child.businessPurpose == BusinessPurpose.advanceSettlement,
    );
    final advanceAmount =
        parentTransaction.amountOf(TransactionRole.receivable) ??
        parentTransaction.primaryAmount;
    return AdvanceSummary(
      advanceAmount: advanceAmount,
      refundedAmount: refunded,
      advanceRefundedAmount: advanceRefunded,
      refundableAmount: parentTransaction.primaryAmount - refunded,
      receivedAmount: received,
      gapAmount: gap,
      outstanding: calculateAdvanceOutstanding(
        advanceAmount: advanceAmount,
        refundedAdvanceAmount: advanceRefunded,
        receivedTotal: received,
        isClosed: closed,
      ),
      isClosed: closed,
    );
  }

  Money _sumSettlementIn({
    required Set<BusinessPurpose> purposes,
    String? excludingTransactionId,
  }) {
    return childTransactions
        .where(
          (transaction) =>
              purposes.contains(transaction.businessPurpose) &&
              transaction.id != excludingTransactionId,
        )
        .fold(
          Money.zero(),
          (sum, transaction) =>
              sum +
              (transaction.amountOf(TransactionRole.settlementIn) ??
                  Money.zero()),
        );
  }

  bool get advanceSettled => _advanceSummary()?.isClosed ?? false;

  void updateReportingFlags({
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
  }) {
    for (final transaction in transactions) {
      transaction.updateReportingFlags(
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
      );
    }
  }
}

/// Refund facts calculated from the parent and refund child transaction lines.
class RefundSummary {
  const RefundSummary({
    required this.refundedTotal,
    required this.originalCategoryAllocations,
    required this.refundedCategoryAllocations,
  });

  final Money refundedTotal;
  final List<AccountAmountAllocation> originalCategoryAllocations;
  final List<AccountAmountAllocation> refundedCategoryAllocations;

  List<AccountAmountAllocation> get remainingCategoryAllocations =>
      subtractAllocations(
        base: originalCategoryAllocations,
        reductions: refundedCategoryAllocations,
      );

  List<RefundCategorySummary> get categories {
    final originalByAccount = <String, int>{};
    final refundedByAccount = <String, int>{};
    final order = <String>[];
    for (final allocation in originalCategoryAllocations) {
      if (!originalByAccount.containsKey(allocation.accountId)) {
        order.add(allocation.accountId);
      }
      originalByAccount[allocation.accountId] =
          (originalByAccount[allocation.accountId] ?? 0) +
          allocation.amount.minorUnits;
    }
    for (final allocation in refundedCategoryAllocations) {
      refundedByAccount[allocation.accountId] =
          (refundedByAccount[allocation.accountId] ?? 0) +
          allocation.amount.minorUnits;
    }
    return [
      for (final accountId in order)
        RefundCategorySummary(
          accountId: accountId,
          originalAmount: Money(minorUnits: originalByAccount[accountId] ?? 0),
          refundedAmount: Money(minorUnits: refundedByAccount[accountId] ?? 0),
        ),
    ];
  }
}

class RefundCategorySummary {
  const RefundCategorySummary({
    required this.accountId,
    required this.originalAmount,
    required this.refundedAmount,
  });

  final String accountId;
  final Money originalAmount;
  final Money refundedAmount;

  Money get remainingAmount => originalAmount - refundedAmount;
}

class AdvanceSummary {
  const AdvanceSummary({
    required this.advanceAmount,
    this.refundedAmount = const Money(minorUnits: 0),
    this.advanceRefundedAmount = const Money(minorUnits: 0),
    this.refundableAmount,
    required this.receivedAmount,
    this.gapAmount = const Money(minorUnits: 0),
    required this.outstanding,
    required this.isClosed,
  });

  final Money advanceAmount;
  final Money refundedAmount;
  final Money advanceRefundedAmount;
  final Money? refundableAmount;
  final Money receivedAmount;
  final Money gapAmount;
  final Money outstanding;
  final bool isClosed;
}

/// 读写两侧共享的逐笔垫付待收回规则。
Money calculateAdvanceOutstanding({
  required Money advanceAmount,
  required Money refundedAdvanceAmount,
  required Money receivedTotal,
  required bool isClosed,
}) {
  if (isClosed) return Money.zero();
  return advanceAmount - refundedAdvanceAmount - receivedTotal;
}
