import '../entity/account.dart';
import '../entity/transaction.dart';

class AccountBook {
  const AccountBook();

  List<Account> applyTransactions(
    Map<int, Account> accounts,
    Iterable<Transaction> transactions,
  ) {
    final updated = Map<int, Account>.of(accounts);
    for (final transaction in transactions) {
      for (final accountId in transaction.accountIds) {
        final account = updated[accountId];
        if (account == null) {
          throw StateError('Account $accountId does not exist.');
        }
        updated[accountId] = account.applyTransaction(transaction);
      }
    }
    return updated.values.toList();
  }
}
