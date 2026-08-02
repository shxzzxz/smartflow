import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

abstract interface class AccountQueryRepository {
  Future<Account?> findAccountById(String id);

  Stream<List<Account>> watchAccounts(Set<AccountType> types);

  /// 全量账户（含归档），供按 id 解析历史分录的名称/元数据。
  Stream<List<Account>> watchAllAccounts();

  Stream<List<Account>> watchCategories(AccountType type);

  Stream<List<Account>> watchArchivedCategories(AccountType type);
}
