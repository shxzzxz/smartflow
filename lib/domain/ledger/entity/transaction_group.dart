import '../../../core/money/money.dart';
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

  Money refundedTotal() {
    return childTransactions
        .where(
          (transaction) =>
              transaction.businessPurpose == BusinessPurpose.refund,
        )
        .fold(
          Money.zero(),
          (sum, transaction) => sum + transaction.primaryAmount,
        );
  }

  Money reimbursementReceivedTotal() {
    return childTransactions
        .where(
          (transaction) =>
              transaction.businessPurpose ==
                  BusinessPurpose.reimbursementReceipt ||
              transaction.businessPurpose == BusinessPurpose.reimbursementClose,
        )
        .fold(
          Money.zero(),
          (sum, transaction) => sum + transaction.primaryAmount,
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
