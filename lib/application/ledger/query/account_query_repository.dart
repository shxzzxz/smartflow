import '../../../domain/ledger/entity/account.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';

abstract interface class AccountQueryRepository {
  Stream<List<Account>> watchAccounts(Set<AccountType> types);

  Stream<List<Account>> watchCategories(AccountType type);
}
