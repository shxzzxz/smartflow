import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/accounting/entities/account.dart';
import '../../../domain/accounting/enums/accounting_enums.dart';
import '../../../domain/accounting/repositories/account_repository.dart';
import '../../../domain/accounting/repositories/system_account_resolver.dart';
import '../../app_database.dart';
import '../../patch_value.dart';

class DriftAccountRepository implements AccountRepository, CategoryRepository {
  DriftAccountRepository(
    this._database, {
    SystemAccountResolver? systemAccounts,
  });

  final AppDatabase _database;

  @override
  Future<Account?> findAccountById(int id) async {
    final row =
        await (_database.select(_database.accounts)
          ..where((account) => account.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapAccount(row);
  }

  @override
  Future<List<Account>> findAccountsByIds(Set<int> ids) async {
    if (ids.isEmpty) {
      return const [];
    }

    final rows =
        await (_database.select(_database.accounts)
          ..where((account) => account.id.isIn(ids))).get();
    return rows.map(_mapAccount).toList();
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

    return query.watch().map((rows) => rows.map(_mapAccount).toList());
  }

  @override
  Future<Account> createAccount(AccountInsertSpec spec) {
    return _database.transaction(() async {
      final now = DateTime.now();
      final accountId = await _database
          .into(_database.accounts)
          .insert(
            AccountsCompanion.insert(
              name: spec.name,
              accountType: spec.type,
              accountSubtype: Value(spec.subtype),
              currencyCode: spec.currencyCode,
              balanceMinor: const Value(0),
              iconKey: Value(spec.iconKey),
              note: Value(spec.note),
              creditLimitMinor: Value(spec.creditLimitMinor),
              billingDay: Value(spec.billingDay),
              repaymentDay: Value(spec.repaymentDay),
              sortOrder: Value(spec.sortOrder),
              isHidden: Value(spec.isHidden),
              source: const Value(AccountSource.user),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final row =
          await (_database.select(_database.accounts)
            ..where((account) => account.id.equals(accountId))).getSingle();
      return _mapAccount(row);
    });
  }

  @override
  Future<void> updateAccount(int id, AccountUpdateSpec spec) {
    return _database.transaction(() async {
      final now = DateTime.now();
      await (_database.update(_database.accounts)
        ..where((account) => account.id.equals(id))).write(
        AccountsCompanion(
          name: spec.name == null ? const Value.absent() : Value(spec.name!),
          accountSubtype: spec.subtype.toValue(),
          iconKey: spec.iconKey.toValue(),
          note: spec.note.toValue(),
          creditLimitMinor: spec.creditLimitMinor.toValue(),
          billingDay: spec.billingDay.toValue(),
          repaymentDay: spec.repaymentDay.toValue(),
          sortOrder:
              spec.sortOrder == null
                  ? const Value.absent()
                  : Value(spec.sortOrder!),
          isHidden:
              spec.isHidden == null
                  ? const Value.absent()
                  : Value(spec.isHidden!),
          updatedAt: Value(now),
        ),
      );
    });
  }

  @override
  Future<Account?> findCategoryById(int id) async {
    final row =
        await (_database.select(_database.accounts)..where(
          (account) =>
              account.id.equals(id) &
              account.accountType.isInValues({
                AccountType.income,
                AccountType.expense,
              }),
        )).getSingleOrNull();
    return row == null ? null : _mapAccount(row);
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

    return query.watch().map((rows) => rows.map(_mapAccount).toList());
  }

  @override
  Future<Account> createCategory(CategoryInsertSpec spec) async {
    final now = DateTime.now();
    final id = await _database
        .into(_database.accounts)
        .insert(
          AccountsCompanion.insert(
            name: spec.name,
            accountType: spec.type,
            parentId: Value(spec.parentId),
            currencyCode: spec.currencyCode,
            iconKey: Value(spec.iconKey),
            note: Value(spec.note),
            sortOrder: Value(spec.sortOrder),
            source: const Value(AccountSource.user),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final row =
        await (_database.select(_database.accounts)
          ..where((account) => account.id.equals(id))).getSingle();
    return _mapAccount(row);
  }

  Account _mapAccount(AccountRow row) {
    return Account(
      id: row.id,
      name: row.name,
      type: row.accountType,
      subtype: row.accountSubtype,
      parentId: row.parentId,
      currencyCode: row.currencyCode,
      balance: Money(minorUnits: row.balanceMinor, currency: row.currencyCode),
      iconKey: row.iconKey,
      note: row.note,
      creditLimit:
          row.creditLimitMinor == null
              ? null
              : Money(
                minorUnits: row.creditLimitMinor!,
                currency: row.currencyCode,
              ),
      billingDay: row.billingDay,
      repaymentDay: row.repaymentDay,
      sortOrder: row.sortOrder,
      isHidden: row.isHidden,
      archivedAt: row.archivedAt,
      systemKey: row.systemKey,
      source: row.source,
    );
  }
}
