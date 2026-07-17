import '../../entity/account.dart';
import '../../entity/transaction.dart';

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
