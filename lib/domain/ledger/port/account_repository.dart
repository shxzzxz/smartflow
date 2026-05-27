import '../entity/account.dart';

abstract interface class AccountRepository {
  Future<Account?> findById(int id);

  Future<List<Account>> findByIds(Set<int> ids);

  Future<Account> create(Account account);

  Future<void> save(Account account);
}
