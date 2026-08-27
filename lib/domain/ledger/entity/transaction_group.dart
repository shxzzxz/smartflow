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
    return _sumChildren(
      purposes: const {BusinessPurpose.refund},
      excludingTransactionId: excludingTransactionId,
    );
  }

  Money reimbursementReceivedTotal({String? excludingTransactionId}) {
    return _sumChildren(
      purposes: const {
        BusinessPurpose.reimbursementReceipt,
        BusinessPurpose.reimbursementClose,
      },
      excludingTransactionId: excludingTransactionId,
    );
  }

  Money reimbursementOutstanding() {
    return calculateReimbursementOutstanding(
      advanceAmount: parentTransaction.primaryAmount,
      refundedTotal: refundedTotal(),
      receivedTotal: reimbursementReceivedTotal(),
      isClosed: reimbursementClosed,
    );
  }

  /// 排除某笔子交易后的待核销额。
  ///
  /// 重建该子交易时用它推导待核销与报销差额,避免把子交易自己的派生分项读回来
  /// 当输入。
  Money reimbursementOutstandingExcluding(String childTransactionId) {
    return parentTransaction.primaryAmount -
        refundedTotal(excludingTransactionId: childTransactionId) -
        reimbursementReceivedTotal(excludingTransactionId: childTransactionId);
  }

  List<AccountAmountAllocation> get categoryAllocations {
    final role = switch (parentTransaction.businessPurpose) {
      BusinessPurpose.dailyExpense => TransactionRole.category,
      BusinessPurpose.reimbursementAdvance =>
        TransactionRole.reimbursementExpenseCategory,
      _ => null,
    };
    if (role == null) return const [];
    return [
      for (final line in parentTransaction.linesOf(role))
        AccountAmountAllocation(
          accountId: line.accountId!,
          amount: line.amount,
        ),
    ];
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
    return subtractAllocations(
      base: categoryAllocations,
      reductions: [
        for (final refund in childTransactions.where(
          (child) =>
              child.businessPurpose == BusinessPurpose.refund &&
              child.id != excludingTransactionId,
        ))
          ...refundCategoryAllocations(refund),
      ],
    );
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

  Money _sumChildren({
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

  bool get reimbursementClosed => childTransactions.any(
    (transaction) =>
        transaction.businessPurpose == BusinessPurpose.reimbursementClose,
  );

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
