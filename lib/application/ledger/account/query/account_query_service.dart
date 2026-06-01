import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/account_usage.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import 'account_query_repository.dart';

abstract interface class AccountQueryService {
  Future<Account?> findAccountById(String id);

  Stream<List<Account>> watchAccounts(Set<AccountType> types);

  Stream<Map<String, Account>> watchAccountsById();

  Stream<List<Account>> watchAccountsForUsage(AccountUsage usage);

  Stream<List<Account>> watchCategories(AccountType type);
}

class AccountQueryServiceImpl implements AccountQueryService {
  const AccountQueryServiceImpl({required AccountQueryRepository accounts})
    : _accounts = accounts;

  final AccountQueryRepository _accounts;

  @override
  Future<Account?> findAccountById(String id) {
    return _accounts.findAccountById(id);
  }

  @override
  Stream<List<Account>> watchAccounts(Set<AccountType> types) {
    return _accounts.watchAccounts(types);
  }

  @override
  Stream<Map<String, Account>> watchAccountsById() {
    return watchAccounts({
      AccountType.asset,
      AccountType.liability,
      AccountType.equity,
      AccountType.income,
      AccountType.expense,
    }).map((accounts) => {for (final account in accounts) account.id: account});
  }

  @override
  Stream<List<Account>> watchAccountsForUsage(AccountUsage usage) {
    return watchAccounts({AccountType.asset, AccountType.liability}).map(
      (accounts) =>
          accounts
              .where((account) => accountMatchesUsage(account, usage))
              .toList(),
    );
  }

  @override
  Stream<List<Account>> watchCategories(AccountType type) {
    return _accounts.watchCategories(type);
  }
}
