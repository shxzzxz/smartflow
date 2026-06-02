import '../../../core/money/money.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/transaction_ownership.dart';
import 'transaction.dart';

class RootTransactionGroup {
  const RootTransactionGroup({
    required this.rootTransactionId,
    required this.parentTransaction,
    required this.childTransactions,
  });

  final String rootTransactionId;
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
        .where((tx) => tx.businessPurpose == BusinessPurpose.refund)
        .fold(const Money(minorUnits: 0), (sum, tx) => sum + tx.primaryAmount);
  }

  Money reimbursementReceivedTotal() {
    return childTransactions
        .where(
          (tx) =>
              tx.businessPurpose == BusinessPurpose.reimbursementReceipt ||
              tx.businessPurpose == BusinessPurpose.reimbursementClose,
        )
        .fold(const Money(minorUnits: 0), (sum, tx) => sum + tx.primaryAmount);
  }

  bool get reimbursementClosed {
    return childTransactions.any(
      (tx) => tx.businessPurpose == BusinessPurpose.reimbursementClose,
    );
  }

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

  void updateOwnership(TransactionOwnership ownership) {
    for (final transaction in transactions) {
      transaction.updateOwnership(ownership);
    }
  }
}
