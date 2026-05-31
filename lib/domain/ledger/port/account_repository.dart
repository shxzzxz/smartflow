import '../entity/account.dart';

abstract interface class AccountRepository {
  Future<Account?> findById(String id);

  Future<List<Account>> findByIds(Set<String> ids);

  Future<void> create(Account account);

  Future<void> save(Account account);

  Future<void> saveAll(Iterable<Account> accounts);
}

class AccountVersionConflictException implements Exception {
  const AccountVersionConflictException();
}
