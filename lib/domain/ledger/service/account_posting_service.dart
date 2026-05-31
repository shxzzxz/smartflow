import '../entity/account.dart';
import '../entity/transaction.dart';

abstract interface class AccountPostingService {
  List<Account> apply({
    required Transaction transaction,
    required Map<String, Account> accounts,
  });

  List<Account> applyAll({
    required Iterable<Transaction> transactions,
    required Map<String, Account> accounts,
  });
}

class DefaultAccountPostingService implements AccountPostingService {
  const DefaultAccountPostingService();

  @override
  List<Account> apply({
    required Transaction transaction,
    required Map<String, Account> accounts,
  }) {
    return applyAll(transactions: [transaction], accounts: accounts);
  }

  @override
  List<Account> applyAll({
    required Iterable<Transaction> transactions,
    required Map<String, Account> accounts,
  }) {
    final updated = Map<String, Account>.of(accounts);
    for (final transaction in transactions) {
      for (final accountId in transaction.accountIds) {
        final account = updated[accountId];
        if (account == null) {
          throw StateError('Account $accountId does not exist.');
        }
        account.applyEntryImpacts(transaction.entries);
      }
    }
    return updated.values.toList();
  }
}
