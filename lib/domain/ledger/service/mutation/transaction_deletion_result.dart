import '../../entity/account.dart';
import '../../entity/transaction.dart';

class TransactionDeletionResult {
  const TransactionDeletionResult({
    required this.targetTransactionId,
    required this.deletesGroup,
    required this.deletedTransactions,
    required this.accounts,
  });

  final String targetTransactionId;
  final bool deletesGroup;
  final List<Transaction> deletedTransactions;
  final List<Account> accounts;
}
