import '../entity/account.dart';

abstract interface class AccountRepository {
  Future<Account?> findById(String id);

  Future<List<Account>> findByIds(Set<String> ids);

  Future<Account> create(Account account);

  Future<void> save(Account account);

  Future<void> saveAll(Iterable<Account> accounts);
}
