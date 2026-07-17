import '../entity/account.dart';
import '../entity/transaction.dart';
import '../entity/transaction_group.dart';
import '../service/mutation/transaction_group_rewrite_planner.dart';

class PostingResult {
  const PostingResult({required this.transaction, required this.accounts});

  final Transaction transaction;
  final List<Account> accounts;
}

class TransactionUpdateResult {
  const TransactionUpdateResult({
    required this.transactions,
    required this.accounts,
    required this.currentTransaction,
  });

  final List<Transaction> transactions;
  final List<Account> accounts;
  final Transaction currentTransaction;
}

class TransactionGroupRewriteResult {
  const TransactionGroupRewriteResult({
    required this.plan,
    required this.accounts,
    required this.currentTransaction,
  });

  final TransactionGroupRewritePlan plan;
  final List<Account> accounts;
  final Transaction currentTransaction;

  TransactionGroup get currentGroup => plan.currentGroup;
}

class TransactionDeletionResult {
  const TransactionDeletionResult({
    required this.deletedTransactions,
    required this.accounts,
  });

  final List<Transaction> deletedTransactions;
  final List<Account> accounts;
}
