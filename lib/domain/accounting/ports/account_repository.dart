import '../../../core/patch/patch.dart';
import '../entities/account.dart';
import '../enums/accounting_enums.dart';

abstract interface class AccountRepository {
  Future<Account?> findAccountById(int id);

  Future<List<Account>> findAccountsByIds(Set<int> ids);

  Stream<List<Account>> watchAccounts(Set<AccountType> types);

  Future<Account> createAccount(AccountInsertSpec spec);

  Future<void> updateAccount(int id, AccountUpdateSpec spec);
}

abstract interface class CategoryRepository {
  Future<Account?> findCategoryById(int id);

  Stream<List<Account>> watchCategories(AccountType type);

  Future<Account> createCategory(CategoryInsertSpec spec);
}

class AccountInsertSpec {
  const AccountInsertSpec({
    required this.name,
    required this.type,
    this.subtype,
    this.iconKey,
    this.note,
    this.creditLimitMinor,
    this.billingDay,
    this.repaymentDay,
    this.sortOrder = 0,
    this.isHidden = false,
  });

  final String name;
  final AccountType type;
  final AccountSubtype? subtype;
  final String? iconKey;
  final String? note;
  final int? creditLimitMinor;
  final int? billingDay;
  final int? repaymentDay;
  final int sortOrder;
  final bool isHidden;
}

class AccountUpdateSpec {
  const AccountUpdateSpec({
    this.name,
    this.sortOrder,
    this.isHidden,
    this.subtype,
    this.iconKey,
    this.note,
    this.creditLimitMinor,
    this.billingDay,
    this.repaymentDay,
  });

  final String? name;
  final int? sortOrder;
  final bool? isHidden;
  final Patch<AccountSubtype>? subtype;
  final Patch<String>? iconKey;
  final Patch<String>? note;
  final Patch<int>? creditLimitMinor;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
}

class CategoryInsertSpec {
  const CategoryInsertSpec({
    required this.name,
    required this.type,
    this.parentId,
    this.iconKey,
    this.note,
    this.sortOrder = 0,
  });

  final String name;
  final AccountType type;
  final int? parentId;
  final String? iconKey;
  final String? note;
  final int sortOrder;
}
