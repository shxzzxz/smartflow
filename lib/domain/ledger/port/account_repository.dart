import '../../../core/error/app_error_code.dart';
import '../entity/account.dart';

enum AccountRepositoryErrorCode implements AppErrorCode {
  concurrentUpdate(
    code: 'ledger.account.concurrent_update',
    defaultMessage: '账户并发修改，请稍后重试。',
  );

  const AccountRepositoryErrorCode({
    required this.code,
    required this.defaultMessage,
  });

  @override
  final String code;

  @override
  final String defaultMessage;
}

abstract interface class AccountRepository {
  Future<Account?> findById(String id);

  Future<List<Account>> findByIds(Set<String> ids);

  Future<List<Account>> findChildrenOf(String parentId);

  Future<void> create(Account account);

  Future<void> save(Account account);

  Future<void> saveAll(Iterable<Account> accounts);
}
