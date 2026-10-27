import '../../../core/error/app_error_code.dart';
import '../entity/account.dart';
import '../valobj/ledger_enum.dart';

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

  /// 按展示顺序读取同一父节点下的活跃收入或支出分类。
  Future<List<Account>> findCategorySiblings({
    required AccountType type,
    required String? parentId,
  });

  Future<List<Account>> findByGroupId(String? groupId);

  Future<void> create(Account account);

  Future<void> save(Account account);

  Future<void> saveAll(Iterable<Account> accounts);

  /// 物理删除。仅用于无业务引用的分类或已归档用户账户，调用方负责前置校验。
  Future<void> delete(String id);
}
