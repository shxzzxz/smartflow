import 'package:drift/drift.dart';

import '../../../application/ledger/query/account_query_repository.dart';
import '../../../domain/ledger/entity/account.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../domain/ledger/port/account_repository.dart';
import 'package:smartflow/data/app_database.dart';
import '../mapper/account_mapper.dart';

class DriftAccountRepository
    implements AccountRepository, AccountQueryRepository {
  DriftAccountRepository(this._database);

  final AppDatabase _database;

  @override
  Future<Account?> findById(String id) => findAccountById(id);

  @override
  Future<List<Account>> findByIds(Set<String> ids) => findAccountsByIds(ids);

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
  Stream<List<Account>> watchAccounts(Set<AccountType> types) {
    final query =
        _database.select(_database.accounts)
          ..where(
            (account) =>
                account.archivedAt.isNull() &
                account.accountType.isInValues(types),
          )
          ..orderBy([
            (account) => OrderingTerm.asc(account.sortOrder),
            (account) => OrderingTerm.asc(account.name),
          ]);

    return query.watch().map((rows) => rows.map(mapAccount).toList());
  }

  @override
  Future<Account> create(Account account) {
    final now = DateTime.now();
    return _database
        .into(_database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: account.id,
            name: account.name,
            accountType: account.type,
            accountSubtype: Value(account.subtype),
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
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        )
        .then(
          (_) => (_database.select(_database.accounts)
            ..where((row) => row.id.equals(account.id))).getSingle(),
        )
        .then(mapAccount);
  }

  @override
  Future<void> save(Account account) {
    final now = DateTime.now();
    return (_database.update(_database.accounts)
      ..where((row) => row.id.equals(account.id))).write(
      AccountsCompanion(
        name: Value(account.name),
        accountSubtype: Value(account.subtype),
        parentId: Value(account.parentId),
        iconKey: Value(account.iconKey),
        note: Value(account.note),
        creditLimitMinor: Value(account.creditLimit?.minorUnits),
        billingDay: Value(account.billingDay),
        repaymentDay: Value(account.repaymentDay),
        sortOrder: Value(account.sortOrder),
        isHidden: Value(account.isHidden),
        archivedAt: Value(account.archivedAt),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> saveAll(Iterable<Account> accounts) {
    final now = DateTime.now();
    return Future.forEach<Account>(accounts, (account) {
      return (_database.update(_database.accounts)
        ..where((row) => row.id.equals(account.id))).write(
        AccountsCompanion(
          balanceMinor: Value(account.balance.minorUnits),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<Account?> findCategoryById(String id) async {
    final row =
        await (_database.select(_database.accounts)..where(
          (account) =>
              account.id.equals(id) &
              account.accountType.isInValues({
                AccountType.income,
                AccountType.expense,
              }),
        )).getSingleOrNull();
    return row == null ? null : mapAccount(row);
  }

  @override
  Stream<List<Account>> watchCategories(AccountType type) {
    final query =
        _database.select(_database.accounts)
          ..where(
            (account) =>
                account.archivedAt.isNull() &
                account.accountType.equalsValue(type),
          )
          ..orderBy([
            (account) => OrderingTerm.asc(account.parentId),
            (account) => OrderingTerm.asc(account.sortOrder),
            (account) => OrderingTerm.asc(account.name),
          ]);

    return query.watch().map((rows) => rows.map(mapAccount).toList());
  }
}
