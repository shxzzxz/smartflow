import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/infrastructure/accounting/repositories/drift_balance_aggregate_repository.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/application/accounting/accounting_api.dart';

import '../../../helpers/test_app_database.dart';

void main() {
  group('FinancialMetricsServiceImpl', () {
    late AppDatabase database;
    late FinancialMetricsServiceImpl service;

    setUp(() {
      database = createTestDatabase();
      service = FinancialMetricsServiceImpl(
        DriftBalanceAggregateRepository(database),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'cashflow comparison aggregates same period and previous full month',
      () async {
        final wallet = await _insertAccount(database, '钱包', AccountType.asset);
        final food = await _insertAccount(database, '餐饮', AccountType.expense);
        final salary = await _insertAccount(database, '工资', AccountType.income);

        await _post(
          database,
          occurredAt: DateTime(2026, 4, 10),
          entries: [
            _Entry(wallet, EntryDirection.debit, 100000),
            _Entry(salary, EntryDirection.credit, 100000),
          ],
        );
        await _post(
          database,
          occurredAt: DateTime(2026, 4, 20),
          entries: [
            _Entry(wallet, EntryDirection.debit, 40000),
            _Entry(salary, EntryDirection.credit, 40000),
          ],
        );
        await _post(
          database,
          occurredAt: DateTime(2026, 5, 10),
          entries: [
            _Entry(wallet, EntryDirection.debit, 150000),
            _Entry(salary, EntryDirection.credit, 150000),
          ],
        );
        await _post(
          database,
          occurredAt: DateTime(2026, 5, 11),
          entries: [
            _Entry(food, EntryDirection.debit, 50000),
            _Entry(wallet, EntryDirection.credit, 50000),
          ],
        );
        await _post(
          database,
          occurredAt: DateTime(2026, 5, 12),
          entries: [
            _Entry(wallet, EntryDirection.debit, 10000),
            _Entry(food, EntryDirection.credit, 10000),
          ],
        );
        await _post(
          database,
          occurredAt: DateTime(2026, 5, 13),
          isExcludedFromStats: true,
          entries: [
            _Entry(wallet, EntryDirection.debit, 99900),
            _Entry(salary, EntryDirection.credit, 99900),
          ],
        );

        final comparison =
            await service
                .watchCashflowComparison(
                  CashflowComparisonQuery(
                    month: MonthKey(year: 2026, month: 5),
                    asOfDate: DateTime(2026, 5, 12),
                  ),
                )
                .first;

        expect(comparison.previousSamePeriod.income.minorUnits, 100000);
        expect(comparison.previousFullPeriod.income.minorUnits, 140000);
        expect(comparison.current.income.minorUnits, 150000);
        expect(comparison.incomeChange.delta.minorUnits, 50000);
        expect(comparison.incomeChange.ratio, 0.5);
        expect(
          comparison.incomeChange.fullPeriodRatio,
          closeTo(1.0714, 0.0001),
        );
        expect(comparison.current.expense.minorUnits, 40000);
      },
    );

    test('daily cashflow summaries use entries statistics口径', () async {
      final wallet = await _insertAccount(database, '钱包', AccountType.asset);
      final food = await _insertAccount(database, '餐饮', AccountType.expense);
      final fee = await _insertAccount(database, '手续费', AccountType.expense);
      final salary = await _insertAccount(database, '工资', AccountType.income);

      await _post(
        database,
        occurredAt: DateTime(2026, 5, 10, 8),
        entries: [
          _Entry(wallet, EntryDirection.debit, 100000),
          _Entry(salary, EntryDirection.credit, 100000),
        ],
      );
      await _post(
        database,
        occurredAt: DateTime(2026, 5, 10, 12),
        entries: [
          _Entry(food, EntryDirection.debit, 30000),
          _Entry(fee, EntryDirection.debit, 2000),
          _Entry(wallet, EntryDirection.credit, 32000),
        ],
      );
      await _post(
        database,
        occurredAt: DateTime(2026, 5, 10, 18),
        entries: [
          _Entry(wallet, EntryDirection.debit, 5000),
          _Entry(food, EntryDirection.credit, 5000),
        ],
      );
      await _post(
        database,
        occurredAt: DateTime(2026, 5, 11),
        isExcludedFromStats: true,
        entries: [
          _Entry(food, EntryDirection.debit, 99900),
          _Entry(wallet, EntryDirection.credit, 99900),
        ],
      );

      final summaries =
          await service
              .watchDailyCashflowSummaries(
                DailyCashflowSummaryQuery(
                  month: MonthKey(year: 2026, month: 5),
                ),
              )
              .first;

      expect(summaries, hasLength(1));
      expect(summaries.single.date, DateTime(2026, 5, 10));
      expect(summaries.single.income.minorUnits, 100000);
      expect(summaries.single.expense.minorUnits, 27000);
    });

    test(
      'balance sheet comparison and trend use point-in-time balances',
      () async {
        final wallet = await _insertAccount(database, '钱包', AccountType.asset);
        final equity = await _insertAccount(database, '期初', AccountType.equity);
        final food = await _insertAccount(database, '餐饮', AccountType.expense);

        await _post(
          database,
          occurredAt: DateTime(2026, 4, 1),
          entries: [
            _Entry(wallet, EntryDirection.debit, 1000000),
            _Entry(equity, EntryDirection.credit, 1000000),
          ],
        );
        await _post(
          database,
          occurredAt: DateTime(2026, 5, 10),
          entries: [
            _Entry(food, EntryDirection.debit, 200000),
            _Entry(wallet, EntryDirection.credit, 200000),
          ],
        );
        await _post(
          database,
          occurredAt: DateTime(2026, 5, 11),
          isExcludedFromStats: true,
          entries: [
            _Entry(food, EntryDirection.debit, 50000),
            _Entry(wallet, EntryDirection.credit, 50000),
          ],
        );

        final comparison =
            await service
                .watchBalanceSheetComparison(
                  BalanceSheetComparisonQuery(
                    month: MonthKey(year: 2026, month: 5),
                    asOfExclusive: DateTime(2026, 5, 20),
                  ),
                )
                .first;

        expect(comparison.previous.netAssets.minorUnits, 1000000);
        expect(comparison.current.netAssets.minorUnits, 750000);
        expect(comparison.netAssetChange.delta.minorUnits, -250000);

        final trend =
            await service
                .watchNetAssetTrend(
                  NetAssetTrendQuery(
                    endMonth: MonthKey(year: 2026, month: 5),
                    months: 2,
                    currentAsOfExclusive: DateTime(2026, 5, 20),
                  ),
                )
                .first;

        expect(trend.map((point) => point.month.toString()), [
          '2026-04',
          '2026-05',
        ]);
        expect(trend.map((point) => point.netAssets.minorUnits), [
          1000000,
          750000,
        ]);
      },
    );
  });
}

Future<int> _insertAccount(
  AppDatabase database,
  String name,
  AccountType type,
) {
  return database
      .into(database.accounts)
      .insert(AccountsCompanion.insert(name: name, accountType: type));
}

Future<void> _post(
  AppDatabase database, {
  required DateTime occurredAt,
  required List<_Entry> entries,
  bool isExcludedFromStats = false,
}) async {
  final transactionId = await database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: occurredAt,
          primaryAmountMinor: entries.first.amountMinor,
          mutationKind: MutationKind.original,
          businessState: BusinessState.current,
          isExcludedFromStats: Value(isExcludedFromStats),
          sourceKind: SourceKind.manual,
        ),
      );

  await (database.update(database.transactions)..where(
    (row) => row.id.equals(transactionId),
  )).write(TransactionsCompanion(rootTransactionId: Value(transactionId)));

  await database.batch((batch) {
    batch.insertAll(database.entries, [
      for (final entry in entries)
        EntriesCompanion.insert(
          transactionId: transactionId,
          accountId: entry.accountId,
          direction: entry.direction,
          amountMinor: entry.amountMinor,
        ),
    ]);
  });
}

class _Entry {
  const _Entry(this.accountId, this.direction, this.amountMinor);

  final int accountId;
  final EntryDirection direction;
  final int amountMinor;
}
