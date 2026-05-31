import 'package:drift/drift.dart';

import '../../../application/ledger/query/account_query_repository.dart';
import '../../../domain/ledger/entity/account.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/data/app_database.dart';
import '../mapper/account_mapper.dart';

class DriftAccountQueryRepository implements AccountQueryRepository {
  DriftAccountQueryRepository(this._database);

  final AppDatabase _database;

  @override
  Future<Account?> findAccountById(String id) async {
    final row =
        await (_database.select(_database.accounts)
          ..where((account) => account.id.equals(id))).getSingleOrNull();
    return row == null ? null : mapAccount(row);
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
