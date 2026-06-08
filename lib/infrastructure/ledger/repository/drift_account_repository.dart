import 'package:drift/drift.dart';
import 'package:smartflow/core/error/app_exception.dart';

import '../../../domain/ledger/entity/account.dart';
import '../../../domain/ledger/port/account_repository.dart';
import '../../database/app_database.dart';
import '../mapper/account_mapper.dart';

class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(this._database);

  final AppDatabase _database;

  @override
  Future<Account?> findById(String id) => findAccountById(id);

  @override
  Future<List<Account>> findByIds(Set<String> ids) => findAccountsByIds(ids);

  @override
  Future<List<Account>> findChildrenOf(String parentId) async {
    final rows =
        await (_database.select(_database.accounts)..where(
          (account) =>
              account.archivedAt.isNull() & account.parentId.equals(parentId),
        )).get();
    return rows.map(mapAccount).toList();
  }

  Future<Account?> findAccountById(String id) async {
    final row =
        await (_database.select(_database.accounts)
          ..where((account) => account.id.equals(id))).getSingleOrNull();
    return row == null ? null : mapAccount(row);
  }

  Future<List<Account>> findAccountsByIds(Set<String> ids) async {
    if (ids.isEmpty) {
      return const [];
    }

    final rows =
        await (_database.select(_database.accounts)
          ..where((account) => account.id.isIn(ids))).get();
    return rows.map(mapAccount).toList();
  }

  @override
  Future<void> create(Account account) {
    final now = DateTime.now();
    return _database
        .into(_database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: account.id,
            name: account.name,
            accountType: account.type,
            accountSubtype: Value(account.subtype),
            accountProfileKey: Value(account.profileKey),
            parentId: Value(account.parentId),
            balanceMinor: const Value(0),
            iconKey: Value(account.iconKey),
            note: Value(account.note),
            creditLimitMinor: Value(account.creditLimit?.minorUnits),
            billingDay: Value(account.billingDay),
            repaymentDay: Value(account.repaymentDay),
            sortOrder: Value(account.sortOrder),
            isHidden: Value(account.isHidden),
            systemKey: Value(account.systemKey),
            source: Value(account.source),
            version: Value(account.version),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  @override
  Future<void> save(Account account) {
    return _updateAccount(account);
  }

  @override
  Future<void> saveAll(Iterable<Account> accounts) {
    return Future.forEach<Account>(accounts, (account) {
      return _updateAccount(account);
    });
  }

  Future<void> _updateAccount(Account account) async {
    final now = DateTime.now();
    final updatedCount = await (_database.update(_database.accounts)..where(
      (row) => row.id.equals(account.id) & row.version.equals(account.version),
    )).write(
      AccountsCompanion(
        name: Value(account.name),
        accountSubtype: Value(account.subtype),
        accountProfileKey: Value(account.profileKey),
        parentId: Value(account.parentId),
        balanceMinor: Value(account.balance.minorUnits),
        iconKey: Value(account.iconKey),
        note: Value(account.note),
        creditLimitMinor: Value(account.creditLimit?.minorUnits),
        billingDay: Value(account.billingDay),
        repaymentDay: Value(account.repaymentDay),
        sortOrder: Value(account.sortOrder),
        isHidden: Value(account.isHidden),
        archivedAt: Value(account.archivedAt),
        version: Value(account.version + 1),
        updatedAt: Value(now),
      ),
    );
    if (updatedCount != 1) {
      throw BusinessException(AccountRepositoryErrorCode.concurrentUpdate);
    }
    account.version += 1;
  }
}
