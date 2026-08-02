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

  /// active 子分类（findChildrenOf 已排除归档节点）之外，
  /// 查挂在 [categoryIds] 上的归档挂载节点（archived 且 parentId 指向其一）。
  Future<List<Account>> findArchivedMountsOf(Set<String> categoryIds);

  /// 物理删除。仅用于无分录引用且无归档挂载的分类，调用方负责前置校验。
  Future<void> delete(String id);
}
