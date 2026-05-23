import 'package:drift/drift.dart';

import '../../../domain/accounting/enums/accounting_enums.dart';
import '../../../domain/accounting/queries/transaction_scope.dart';
import '../../../domain/accounting/repositories/balance_aggregate_repository.dart';
import '../../app_database.dart';
import '../sql/balance_expressions.dart';

class DriftBalanceAggregateRepository implements BalanceAggregateRepository {
  const DriftBalanceAggregateRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Map<AccountType, int>> aggregateByAccountType({
    required Set<AccountType> accountTypes,
    required String currencyCode,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) async {
    if (accountTypes.isEmpty) return const {};

    final deltaExpr = balanceDeltaExpr(
      entries: _db.entries,
      accounts: _db.accounts,
    );
    final sumExpr = deltaExpr.sum();
    final typeCol = _db.accounts.accountType;

    final select = _db.selectOnly(_db.entries).join([
      innerJoin(
        _db.transactions,
        _db.transactions.id.equalsExp(_db.entries.transactionId),
      ),
      innerJoin(
        _db.accounts,
        _db.accounts.id.equalsExp(_db.entries.accountId),
      ),
    ])
      ..addColumns([typeCol, sumExpr])
      ..where(
        applyTransactionScope(
          transactions: _db.transactions,
          scope: scope,
        ),
      )
      ..where(_db.transactions.currencyCode.equals(currencyCode))
      ..where(_db.accounts.accountType.isInValues(accountTypes))
      ..groupBy([typeCol]);

    if (window.from != null) {
      select.where(_db.transactions.occurredAt.isBiggerOrEqualValue(window.from!));
    }
    if (window.until != null) {
      select.where(_db.transactions.occurredAt.isSmallerThanValue(window.until!));
    }

    final rows = await select.get();
    final result = <AccountType, int>{};
    for (final row in rows) {
      final typeName = row.read(typeCol);
      final sum = row.read(sumExpr);
      if (typeName == null) continue;
      final type = AccountType.values.byName(typeName);
      result[type] = sum ?? 0;
    }
    return result;
  }

  @override
  Future<List<Map<AccountType, int>>> aggregateByAccountTypeAtCutoffs({
    required Set<AccountType> accountTypes,
    required String currencyCode,
    required TransactionScopeFilter scope,
    required List<DateTimeWindow> windows,
  }) async {
    final results = <Map<AccountType, int>>[];
    for (final window in windows) {
      results.add(
        await aggregateByAccountType(
          accountTypes: accountTypes,
          currencyCode: currencyCode,
          scope: scope,
          window: window,
        ),
      );
    }
    return results;
  }

  @override
  Future<Map<DateTime, Map<AccountType, int>>> aggregateByAccountTypeByDay({
    required Set<AccountType> accountTypes,
    required String currencyCode,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) async {
    if (accountTypes.isEmpty) return const {};

    final occurredAtCol = _db.transactions.occurredAt;
    final typeCol = _db.accounts.accountType;
    final sumExpr = balanceDeltaExpr(
      entries: _db.entries,
      accounts: _db.accounts,
    ).sum();

    final select = _db.selectOnly(_db.entries).join([
      innerJoin(
        _db.transactions,
        _db.transactions.id.equalsExp(_db.entries.transactionId),
      ),
      innerJoin(
        _db.accounts,
        _db.accounts.id.equalsExp(_db.entries.accountId),
      ),
    ])
      ..addColumns([occurredAtCol, typeCol, sumExpr])
      ..where(
        applyTransactionScope(
          transactions: _db.transactions,
          scope: scope,
        ),
      )
      ..where(_db.transactions.currencyCode.equals(currencyCode))
      ..where(_db.accounts.accountType.isInValues(accountTypes))
      ..groupBy([occurredAtCol, typeCol]);

    if (window.from != null) {
      select.where(_db.transactions.occurredAt.isBiggerOrEqualValue(window.from!));
    }
    if (window.until != null) {
      select.where(_db.transactions.occurredAt.isSmallerThanValue(window.until!));
    }

    final rows = await select.get();
    final result = <DateTime, Map<AccountType, int>>{};
    for (final row in rows) {
      final occurredAt = row.read(occurredAtCol);
      final typeName = row.read(typeCol);
      final sum = row.read(sumExpr) ?? 0;
      if (occurredAt == null || typeName == null) continue;
      final date = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
      final type = AccountType.values.byName(typeName);
      final dayMap = result.putIfAbsent(date, () => <AccountType, int>{});
      dayMap.update(type, (v) => v + sum, ifAbsent: () => sum);
    }
    return result;
  }

  @override
  Stream<void> watchChanges() async* {
    yield null;
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.transactions,
        _db.entries,
        _db.accounts,
      ]),
    )) {
      yield null;
    }
  }
}
