import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/account_usage.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import 'account_query_repository.dart';

abstract interface class AccountQueryService {
  Future<Account?> findAccountById(String id);

  Future<List<Account>> findAccounts(Set<AccountType> types);

  Future<Map<String, Account>> findAccountsById();

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
  Future<List<Account>> findAccounts(Set<AccountType> types) {
    return watchAccounts(types).first;
  }

  @override
  Future<Map<String, Account>> findAccountsById() {
    return watchAccountsById().first;
  }

  @override
  Stream<List<Account>> watchAccounts(Set<AccountType> types) {
    return _accounts.watchAccounts(types);
  }

  /// 含归档账户：历史分录可能引用归档账户/分类，按 id 解析必须全量。
  /// 候选/选择场景不要用这个，走 watchAccounts / watchAccountsForUsage。
  @override
  Stream<Map<String, Account>> watchAccountsById() {
    return _accounts.watchAllAccounts().map(
      (accounts) => {for (final account in accounts) account.id: account},
    );
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
