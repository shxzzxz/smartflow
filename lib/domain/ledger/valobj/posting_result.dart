import '../entity/account.dart';
import '../entity/root_transaction_group.dart';
import '../entity/transaction.dart';

class PostingResult {
  const PostingResult({required this.transaction, required this.accounts});

  final Transaction transaction;
  final List<Account> accounts;
}

class MutationResult {
  const MutationResult({
    required this.transactions,
    required this.accounts,
    required this.currentTransaction,
  });

  final List<Transaction> transactions;
  final List<Account> accounts;
  final Transaction currentTransaction;
}

class ParentReplacementResult extends MutationResult {
  const ParentReplacementResult({
    required super.transactions,
    required super.accounts,
    required super.currentTransaction,
    required this.currentGroup,
  });

  final RootTransactionGroup currentGroup;
}

class ChildReplacementResult extends MutationResult {
  const ChildReplacementResult({
    required super.transactions,
    required super.accounts,
    required super.currentTransaction,
    required this.currentGroup,
  });

  final RootTransactionGroup currentGroup;
}

class CancellationResult {
  const CancellationResult({
    required this.transactions,
    required this.accounts,
  });

  final List<Transaction> transactions;
  final List<Account> accounts;
}

class TransactionUpdateResult {
  const TransactionUpdateResult({
    required this.transactions,
    required this.accounts,
  });

  final List<Transaction> transactions;
  final List<Account> accounts;
}

class TransactionReplacement {
  const TransactionReplacement({
    required this.replacedTransaction,
    required this.reversalTransaction,
    required this.correctionTransaction,
  });

  final Transaction replacedTransaction;
  final Transaction reversalTransaction;
  final Transaction correctionTransaction;

  Iterable<Transaction> get transactions => [
    replacedTransaction,
    reversalTransaction,
    correctionTransaction,
  ];

  Iterable<Transaction> get postingTransactions => [
    reversalTransaction,
    correctionTransaction,
  ];
}

class TransactionCancellation {
  const TransactionCancellation({
    required this.canceledTransaction,
    required this.reversalTransaction,
  });

  final Transaction canceledTransaction;
  final Transaction reversalTransaction;

  Iterable<Transaction> get transactions => [
    canceledTransaction,
    reversalTransaction,
  ];

  Iterable<Transaction> get postingTransactions => [reversalTransaction];
}

class ChildTransactionMigration {
  const ChildTransactionMigration({
    required this.originalChild,
    required this.replacementCandidate,
  });

  final Transaction originalChild;
  final Transaction replacementCandidate;
}
