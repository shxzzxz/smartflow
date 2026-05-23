import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/data/accounting/repositories/drift_balance_aggregate_repository.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/domain/accounting/accounting_api.dart';
import 'package:smartflow/domain/accounting/queries/transaction_scope.dart';
import 'package:smartflow/domain/accounting/repositories/balance_aggregate_repository.dart';

import '../../../helpers/test_app_database.dart';

void main() {
  group('DriftBalanceAggregateRepository', () {
    late AppDatabase database;
    late DriftBalanceAggregateRepository repository;

    setUp(() {
      database = createTestDatabase();
      repository = DriftBalanceAggregateRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('aggregateByAccountType: 资产 + 费用,debit 为正 / credit 为负', () async {
      final wallet = await _insertAccount(database, '钱包', AccountType.asset);
      final food = await _insertAccount(database, '餐饮', AccountType.expense);

      // 收入:+1000 到 wallet
      await _post(database, occurredAt: DateTime(2026, 5, 1), entries: [
        _E(wallet, EntryDirection.debit, 100000),
        _E(food, EntryDirection.credit, 100000),
      ]);
      // 支出:钱包 -300,餐饮 +300
      await _post(database, occurredAt: DateTime(2026, 5, 2), entries: [
        _E(food, EntryDirection.debit, 30000),
        _E(wallet, EntryDirection.credit, 30000),
      ]);

      final result = await repository.aggregateByAccountType(
        accountTypes: {AccountType.asset, AccountType.expense},
        currencyCode: 'CNY',
        scope: TransactionScopeFilter.assetLiability,
      );

      // wallet asset: +100000 - 30000 = 70000
      // food expense: -100000 + 30000 = -70000
      expect(result[AccountType.asset], 70000);
      expect(result[AccountType.expense], -70000);
    });

    test('scope=stats 时排除 is_excluded_from_stats=true', () async {
      final wallet = await _insertAccount(database, '钱包', AccountType.asset);
      final income = await _insertAccount(database, '工资', AccountType.income);

      await _post(database, occurredAt: DateTime(2026, 5, 1), entries: [
        _E(wallet, EntryDirection.debit, 50000),
        _E(income, EntryDirection.credit, 50000),
      ]);
      await _post(database,
          occurredAt: DateTime(2026, 5, 2),
          isExcludedFromStats: true,
          entries: [
            _E(wallet, EntryDirection.debit, 80000),
            _E(income, EntryDirection.credit, 80000),
          ]);

      final stats = await repository.aggregateByAccountType(
        accountTypes: {AccountType.income},
        currencyCode: 'CNY',
        scope: TransactionScopeFilter.stats,
      );
      // 仅含 stats=false 的 50000
      expect(stats[AccountType.income], 50000);

      final assetLiability = await repository.aggregateByAccountType(
        accountTypes: {AccountType.income},
        currencyCode: 'CNY',
        scope: TransactionScopeFilter.assetLiability,
      );
      // 含全部 current 行 130000
      expect(assetLiability[AccountType.income], 130000);
    });

    test('window 时间窗口过滤', () async {
      final wallet = await _insertAccount(database, '钱包', AccountType.asset);
      final salary = await _insertAccount(database, '工资', AccountType.income);

      await _post(database, occurredAt: DateTime(2026, 4, 10), entries: [
        _E(wallet, EntryDirection.debit, 30000),
        _E(salary, EntryDirection.credit, 30000),
      ]);
      await _post(database, occurredAt: DateTime(2026, 5, 10), entries: [
        _E(wallet, EntryDirection.debit, 50000),
        _E(salary, EntryDirection.credit, 50000),
      ]);

      final mayOnly = await repository.aggregateByAccountType(
        accountTypes: {AccountType.asset},
        currencyCode: 'CNY',
        scope: TransactionScopeFilter.assetLiability,
        window: DateTimeWindow(
          from: DateTime(2026, 5, 1),
          until: DateTime(2026, 6, 1),
        ),
      );
      expect(mayOnly[AccountType.asset], 50000);
    });

    test('aggregateByAccountTypeAtCutoffs 多窗口返回与窗口顺序一致', () async {
      final wallet = await _insertAccount(database, '钱包', AccountType.asset);
      final salary = await _insertAccount(database, '工资', AccountType.income);

      await _post(database, occurredAt: DateTime(2026, 4, 10), entries: [
        _E(wallet, EntryDirection.debit, 30000),
        _E(salary, EntryDirection.credit, 30000),
      ]);
      await _post(database, occurredAt: DateTime(2026, 5, 10), entries: [
        _E(wallet, EntryDirection.debit, 50000),
        _E(salary, EntryDirection.credit, 50000),
      ]);

      final cutoffs = await repository.aggregateByAccountTypeAtCutoffs(
        accountTypes: {AccountType.asset},
        currencyCode: 'CNY',
        scope: TransactionScopeFilter.assetLiability,
        windows: [
          DateTimeWindow(until: DateTime(2026, 5, 1)),
          DateTimeWindow(until: DateTime(2026, 6, 1)),
        ],
      );

      expect(cutoffs.length, 2);
      expect(cutoffs[0][AccountType.asset], 30000);
      expect(cutoffs[1][AccountType.asset], 80000);
    });
  });
}

Future<int> _insertAccount(
  AppDatabase database,
  String name,
  AccountType type,
) {
  return database.into(database.accounts).insert(
    AccountsCompanion.insert(
      name: name,
      accountType: type,
      currencyCode: 'CNY',
    ),
  );
}

Future<void> _post(
  AppDatabase database, {
  required DateTime occurredAt,
  required List<_E> entries,
  bool isExcludedFromStats = false,
}) async {
  final transactionId = await database.into(database.transactions).insert(
    TransactionsCompanion.insert(
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: occurredAt,
      currencyCode: 'CNY',
      primaryAmountMinor: entries.first.amountMinor,
      mutationKind: MutationKind.original,
      businessState: BusinessState.current,
      isExcludedFromStats: Value(isExcludedFromStats),
      sourceKind: SourceKind.manual,
    ),
  );

  await (database.update(database.transactions)
        ..where((row) => row.id.equals(transactionId)))
      .write(TransactionsCompanion(rootTransactionId: Value(transactionId)));

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

class _E {
  const _E(this.accountId, this.direction, this.amountMinor);
  final int accountId;
  final EntryDirection direction;
  final int amountMinor;
}
