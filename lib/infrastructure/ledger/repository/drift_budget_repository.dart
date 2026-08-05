import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../../domain/ledger/entity/budget.dart';
import '../../../domain/ledger/port/budget_repository.dart';
import '../../database/app_database.dart';

class DriftBudgetRepository implements BudgetRepository {
  const DriftBudgetRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Budget?> findById(String id) async {
    final query = _db.select(_db.budgets)..where((row) => row.id.equals(id));
    return (await query.getSingleOrNull())?.toDomain();
  }

  @override
  Future<Budget?> findByMonthAndCategory(
    MonthKey month,
    String? categoryId,
  ) async {
    final query =
        _db.select(_db.budgets)
          ..where((row) => row.monthKey.equals(_encodeMonth(month)))
          ..where(
            (row) =>
                categoryId == null
                    ? row.accountId.isNull()
                    : row.accountId.equals(categoryId),
          );
    return (await query.getSingleOrNull())?.toDomain();
  }

  @override
  Future<List<Budget>> findByMonth(MonthKey month) async {
    final query =
        _db.select(_db.budgets)
          ..where((row) => row.monthKey.equals(_encodeMonth(month)))
          ..orderBy([
            (row) => OrderingTerm.asc(row.sortOrder),
            (row) => OrderingTerm.asc(row.id),
          ]);
    return [for (final row in await query.get()) row.toDomain()];
  }

  @override
  Future<void> save(Budget budget) async {
    await _db.into(_db.budgets).insertOnConflictUpdate(budget.toCompanion());
  }

  @override
  Future<void> saveAll(Iterable<Budget> budgets) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.budgets, [
        for (final budget in budgets) budget.toCompanion(),
      ]);
    });
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.budgets)..where((row) => row.id.equals(id))).go();
  }
}

extension on BudgetRow {
  Budget toDomain() {
    return Budget(
      id: id,
      month: _decodeMonth(monthKey),
      categoryId: accountId,
      amount: Money(minorUnits: amountMinor),
      sortOrder: sortOrder,
    );
  }
}

extension on Budget {
  BudgetsCompanion toCompanion() {
    return BudgetsCompanion.insert(
      id: id,
      monthKey: _encodeMonth(month),
      accountId: Value(categoryId),
      amountMinor: amount.minorUnits,
      sortOrder: Value(sortOrder),
      updatedAt: Value(DateTime.now()),
    );
  }
}

int _encodeMonth(MonthKey month) => month.year * 100 + month.month;

MonthKey _decodeMonth(int value) {
  return MonthKey(year: value ~/ 100, month: value % 100);
}
