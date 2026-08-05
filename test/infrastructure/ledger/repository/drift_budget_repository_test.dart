import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/ledger/entity/budget.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_budget_query_source.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_budget_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test('persists total and category budgets with month-local order', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final repository = DriftBudgetRepository(database);
    final month = MonthKey(year: 2026, month: 8);

    await repository.save(
      Budget(
        id: 'total',
        month: month,
        amount: const Money(minorUnits: 200000),
        sortOrder: 0,
      ),
    );
    await repository.save(
      Budget(
        id: 'food',
        month: month,
        categoryId: 'food-category',
        amount: const Money(minorUnits: 100000),
        sortOrder: 1,
      ),
    );

    final saved = await repository.findByMonth(month);
    expect(saved.map((item) => item.id), ['total', 'food']);
    expect(
      (await repository.findByMonthAndCategory(month, null))?.amount,
      const Money(minorUnits: 200000),
    );
  });

  test(
    'budget query includes stats-excluded expense but excludes budget-excluded expense',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await database.batch((batch) {
        batch.insertAll(database.accounts, [
          AccountsCompanion.insert(
            id: 'cash',
            name: '现金',
            accountType: AccountType.asset,
          ),
          AccountsCompanion.insert(
            id: 'food',
            name: '餐饮',
            accountType: AccountType.expense,
          ),
          AccountsCompanion.insert(
            id: 'lunch',
            name: '午餐',
            accountType: AccountType.expense,
            parentId: const Value('food'),
          ),
        ]);
        batch.insertAll(database.budgets, [
          BudgetsCompanion.insert(
            id: 'total-budget',
            monthKey: 202608,
            amountMinor: 200000,
          ),
          BudgetsCompanion.insert(
            id: 'lunch-budget',
            monthKey: 202608,
            accountId: const Value('lunch'),
            amountMinor: 50000,
            sortOrder: const Value(1),
          ),
        ]);
      });
      await _insertExpense(database, id: 'included', amount: 10000);
      await _insertExpense(
        database,
        id: 'stats-excluded',
        amount: 3000,
        excludedFromStats: true,
      );
      await _insertExpense(
        database,
        id: 'budget-excluded',
        amount: 5000,
        excludedFromBudget: true,
      );

      final snapshot =
          await DriftBudgetQuerySource(
            database,
          ).watchMonth(MonthKey(year: 2026, month: 8)).first;

      expect(snapshot.budgets, hasLength(2));
      expect(
        snapshot.categories.map((item) => item.id),
        containsAll(['food', 'lunch']),
      );
      expect(
        snapshot.dailyUsage
            .where((item) => item.categoryId == 'lunch')
            .fold<int>(0, (sum, item) => sum + item.amountMinor),
        13000,
      );
    },
  );
}

Future<void> _insertExpense(
  AppDatabase database, {
  required String id,
  required int amount,
  bool excludedFromStats = false,
  bool excludedFromBudget = false,
}) async {
  final occurredAt = DateTime(2026, 8, 5);
  await database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: id,
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: occurredAt,
          postedAt: occurredAt,
          primaryAmountMinor: amount,
          isExcludedFromStats: Value(excludedFromStats),
          isExcludedFromBudget: Value(excludedFromBudget),
          sourceKind: SourceKind.manual,
        ),
      );
  await database.batch((batch) {
    batch.insertAll(database.entries, [
      EntriesCompanion.insert(
        id: '$id-expense',
        transactionId: id,
        accountId: 'lunch',
        direction: EntryDirection.debit,
        amountMinor: amount,
      ),
      EntriesCompanion.insert(
        id: '$id-cash',
        transactionId: id,
        accountId: 'cash',
        direction: EntryDirection.credit,
        amountMinor: amount,
      ),
    ]);
  });
}
