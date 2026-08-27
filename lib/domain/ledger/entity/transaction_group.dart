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

  Money reimbursementReceivedTotal({String? excludingTransactionId}) {
    return _reimbursementSummary(
          excludingTransactionId: excludingTransactionId,
        )?.receivedAmount ??
        Money.zero();
  }

  /// The only calculation source for refund facts in a transaction group.
  RefundSummary? get refundSummary => _refundSummary();

  /// The only calculation source for reimbursement facts in a transaction group.
  ReimbursementSummary? get reimbursementSummary => _reimbursementSummary();

  Money reimbursementOutstanding() {
    return reimbursementSummary?.outstanding ?? Money.zero();
  }

  /// 排除某笔子交易后的待核销额。
  ///
  /// 重建该子交易时用它推导待核销与报销差额,避免把子交易自己的派生分项读回来
  /// 当输入。
  Money reimbursementOutstandingExcluding(String childTransactionId) {
    return _reimbursementSummary(
          excludingTransactionId: childTransactionId,
        )?.outstanding ??
        Money.zero();
  }

  List<AccountAmountAllocation> get categoryAllocations {
    return refundSummary?.originalCategoryAllocations ?? const [];
  }

  List<AccountAmountAllocation> refundCategoryAllocations(Transaction refund) {
    return [
      for (final line in [
        ...refund.linesOf(TransactionRole.refundOffset),
        ...refund.linesOf(TransactionRole.reimbursementExpenseCategory),
      ])
        AccountAmountAllocation(
          accountId: line.accountId!,
          amount: line.amount,
        ),
    ];
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
      BusinessPurpose.reimbursementAdvance =>
        TransactionRole.reimbursementExpenseCategory,
      _ => null,
    };
    if (role == null) return null;
    final original = [
      for (final line in parentTransaction.linesOf(role))
        AccountAmountAllocation(
          accountId: line.accountId!,
          amount: line.amount,
        ),
    ];
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

  ReimbursementSummary? _reimbursementSummary({
    String? excludingTransactionId,
  }) {
    if (parentTransaction.businessPurpose !=
        BusinessPurpose.reimbursementAdvance) {
      return null;
    }
    final refunded = _sumSettlementIn(
      purposes: const {BusinessPurpose.refund},
      excludingTransactionId: excludingTransactionId,
    );
    final received = _sumSettlementIn(
      purposes: const {
        BusinessPurpose.reimbursementReceipt,
        BusinessPurpose.reimbursementClose,
      },
      excludingTransactionId: excludingTransactionId,
    );
    final gap = childTransactions
        .where((child) => child.id != excludingTransactionId)
        .fold(Money.zero(), (total, child) {
          return total +
              (child.amountOf(TransactionRole.reimbursementGapIncome) ??
                  Money.zero()) -
              (child.amountOf(TransactionRole.reimbursementGapExpense) ??
                  Money.zero());
        });
    final closed = childTransactions.any(
      (child) =>
          child.id != excludingTransactionId &&
          child.businessPurpose == BusinessPurpose.reimbursementClose,
    );
    return ReimbursementSummary(
      advanceAmount: parentTransaction.primaryAmount,
      refundedAmount: refunded,
      receivedAmount: received,
      gapAmount: gap,
      outstanding: calculateReimbursementOutstanding(
        advanceAmount: parentTransaction.primaryAmount,
        refundedTotal: refunded,
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

  bool get reimbursementClosed => _reimbursementSummary()?.isClosed ?? false;

  void updateReportingFlags({
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
  }) {
    for (final transaction in transactions) {
      transaction.updateReportingFlags(
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        parentPurpose: parentTransaction.businessPurpose,
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

class ReimbursementSummary {
  const ReimbursementSummary({
    required this.advanceAmount,
    this.refundedAmount = const Money(minorUnits: 0),
    required this.receivedAmount,
    this.gapAmount = const Money(minorUnits: 0),
    required this.outstanding,
    required this.isClosed,
  });

  final Money advanceAmount;
  final Money refundedAmount;
  final Money receivedAmount;
  final Money gapAmount;
  final Money outstanding;
  final bool isClosed;
}

/// 读写两侧共享的报销待核销规则。
Money calculateReimbursementOutstanding({
  required Money advanceAmount,
  required Money refundedTotal,
  required Money receivedTotal,
  required bool isClosed,
}) {
  if (isClosed) return Money.zero();
  return advanceAmount - refundedTotal - receivedTotal;
}
