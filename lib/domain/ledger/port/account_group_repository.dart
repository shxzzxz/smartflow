import '../entity/account_group.dart';

abstract interface class AccountGroupRepository {
  Future<AccountGroup?> findById(String id);

  Future<List<AccountGroup>> findAll();

  Stream<List<AccountGroup>> watchAll();

  Future<void> create(AccountGroup group);

  Future<void> save(AccountGroup group);

  Future<void> saveAll(Iterable<AccountGroup> groups);

  Future<void> delete(String id);
}
