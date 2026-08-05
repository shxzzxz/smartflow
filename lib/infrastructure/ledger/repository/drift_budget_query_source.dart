import 'package:drift/drift.dart';

import '../../../application/ledger/budget/query/port/budget_query_source.dart';
import '../../../application/ledger/transaction/query/transaction_scope.dart';
import '../../../core/time/month_key.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../../database/app_database.dart';
import '../sql/balance_expressions.dart';

class DriftBudgetQuerySource implements BudgetQuerySource {
  const DriftBudgetQuerySource(this._db);

  final AppDatabase _db;

  @override
  Stream<BudgetQuerySnapshot> watchMonth(MonthKey month) async* {
    yield await _loadMonth(month);
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.budgets,
        _db.accounts,
        _db.transactions,
        _db.entries,
      ]),
    )) {
      yield await _loadMonth(month);
    }
  }

  Future<BudgetQuerySnapshot> _loadMonth(MonthKey month) async {
    final budgetsFuture = _loadBudgets(month);
    final categoriesFuture = _loadCategories();
    final usageFuture = _loadDailyUsage(month);
    return BudgetQuerySnapshot(
      budgets: await budgetsFuture,
      categories: await categoriesFuture,
      dailyUsage: await usageFuture,
    );
  }

  Future<List<BudgetSettingRow>> _loadBudgets(MonthKey month) async {
    final query =
        _db.select(_db.budgets)
          ..where((row) => row.monthKey.equals(month.year * 100 + month.month))
          ..orderBy([
            (row) => OrderingTerm.asc(row.sortOrder),
            (row) => OrderingTerm.asc(row.id),
          ]);
    return [
      for (final row in await query.get())
        BudgetSettingRow(
          id: row.id,
          categoryId: row.accountId,
          amountMinor: row.amountMinor,
          sortOrder: row.sortOrder,
        ),
    ];
  }

  Future<List<BudgetCategoryRow>> _loadCategories() async {
    final query =
        _db.select(_db.accounts)
          ..where((row) => row.accountType.equalsValue(AccountType.expense))
          ..where((row) => row.archivedAt.isNull())
          ..where((row) => row.systemKey.isNull())
          ..orderBy([
            (row) => OrderingTerm.asc(row.sortOrder),
            (row) => OrderingTerm.asc(row.id),
          ]);
    return [
      for (final row in await query.get())
        BudgetCategoryRow(
          id: row.id,
          name: row.name,
          parentId: row.parentId,
          iconKey: row.iconKey,
          sortOrder: row.sortOrder,
        ),
    ];
  }

  Future<List<BudgetDailyUsageRow>> _loadDailyUsage(MonthKey month) async {
    final occurredAt = _db.transactions.occurredAt;
    final categoryId = _db.accounts.id;
    final amount =
        balanceDeltaExpr(entries: _db.entries, accounts: _db.accounts).sum();
    final query =
        _db.selectOnly(_db.entries).join([
            innerJoin(
              _db.transactions,
              _db.transactions.id.equalsExp(_db.entries.transactionId),
            ),
            innerJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.entries.accountId),
            ),
          ])
          ..addColumns([occurredAt, categoryId, amount])
          ..where(
            applyTransactionScope(
              transactions: _db.transactions,
              scope: TransactionScopeFilter.budget,
            ),
          )
          ..where(_db.accounts.accountType.equalsValue(AccountType.expense))
          ..where(_db.accounts.archivedAt.isNull())
          ..where(occurredAt.isBiggerOrEqualValue(month.start))
          ..where(occurredAt.isSmallerThanValue(month.nextMonthStart))
          ..groupBy([occurredAt, categoryId]);

    final byDateAndCategory = <(DateTime, String), int>{};
    for (final row in await query.get()) {
      final timestamp = row.read(occurredAt);
      final id = row.read(categoryId);
      if (timestamp == null || id == null) continue;
      final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
      final key = (date, id);
      byDateAndCategory.update(
        key,
        (value) => value + (row.read(amount) ?? 0),
        ifAbsent: () => row.read(amount) ?? 0,
      );
    }
    final keys =
        byDateAndCategory.keys.toList()..sort((left, right) {
          final dateOrder = left.$1.compareTo(right.$1);
          return dateOrder != 0 ? dateOrder : left.$2.compareTo(right.$2);
        });
    return [
      for (final key in keys)
        BudgetDailyUsageRow(
          date: key.$1,
          categoryId: key.$2,
          amountMinor: byDateAndCategory[key]!,
        ),
    ];
  }
}
