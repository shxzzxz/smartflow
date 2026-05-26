import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';

import '../../../helper/test_app_database.dart';

void main() {
  group('DriftTransactionReadRepository', () {
    late AppDatabase database;
    late DriftTransactionReadRepository repository;

    setUp(() {
      database = createTestDatabase();
      repository = DriftTransactionReadRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('aggregateChildren: 按 rootId 维度对子交易 sum + count', () async {
      final rootId = await _post(
        database,
        purpose: BusinessPurpose.dailyExpense,
        amount: 100000,
      );
      // 2 笔 refund 子交易
      await _post(
        database,
        purpose: BusinessPurpose.refund,
        amount: 30000,
        rootTransactionId: rootId,
        parentTransactionId: rootId,
      );
      await _post(
        database,
        purpose: BusinessPurpose.refund,
        amount: 20000,
        rootTransactionId: rootId,
        parentTransactionId: rootId,
      );
      // 一笔 dailyExpense 的 child(非 refund,不应被计入)
      await _post(
        database,
        purpose: BusinessPurpose.dailyExpense,
        amount: 10000,
        rootTransactionId: rootId,
        parentTransactionId: rootId,
      );

      final result = await repository.aggregateChildren(
        rootIds: {rootId},
        purposes: {BusinessPurpose.refund},
        states: {BusinessState.current},
      );

      expect(result[rootId]?.sumMinor, 50000);
      expect(result[rootId]?.count, 2);
    });

    test('aggregateChildren: 不在 purposes 集合的不计入', () async {
      final rootId = await _post(
        database,
        purpose: BusinessPurpose.reimbursementAdvance,
        amount: 100000,
      );
      await _post(
        database,
        purpose: BusinessPurpose.reimbursementReceipt,
        amount: 60000,
        rootTransactionId: rootId,
        parentTransactionId: rootId,
      );
      await _post(
        database,
        purpose: BusinessPurpose.reimbursementClose,
        amount: 30000,
        rootTransactionId: rootId,
        parentTransactionId: rootId,
      );

      // 只算 receipt
      final receiptOnly = await repository.aggregateChildren(
        rootIds: {rootId},
        purposes: {BusinessPurpose.reimbursementReceipt},
        states: {BusinessState.current},
      );
      expect(receiptOnly[rootId]?.sumMinor, 60000);
      expect(receiptOnly[rootId]?.count, 1);

      // 算 receipt + close
      final combined = await repository.aggregateChildren(
        rootIds: {rootId},
        purposes: {
          BusinessPurpose.reimbursementReceipt,
          BusinessPurpose.reimbursementClose,
        },
        states: {BusinessState.current},
      );
      expect(combined[rootId]?.sumMinor, 90000);
      expect(combined[rootId]?.count, 2);
    });

    test('aggregateChildren: 多 rootId 各自统计', () async {
      final root1 = await _post(
        database,
        purpose: BusinessPurpose.dailyExpense,
        amount: 100000,
      );
      final root2 = await _post(
        database,
        purpose: BusinessPurpose.dailyExpense,
        amount: 50000,
      );
      await _post(
        database,
        purpose: BusinessPurpose.refund,
        amount: 30000,
        rootTransactionId: root1,
        parentTransactionId: root1,
      );
      await _post(
        database,
        purpose: BusinessPurpose.refund,
        amount: 15000,
        rootTransactionId: root2,
        parentTransactionId: root2,
      );

      final result = await repository.aggregateChildren(
        rootIds: {root1, root2},
        purposes: {BusinessPurpose.refund},
        states: {BusinessState.current},
      );

      expect(result[root1]?.sumMinor, 30000);
      expect(result[root2]?.sumMinor, 15000);
    });

    test('findChildren: 按 parentId + states 过滤', () async {
      final parentId = await _post(
        database,
        purpose: BusinessPurpose.dailyExpense,
        amount: 100000,
      );
      await _post(
        database,
        purpose: BusinessPurpose.refund,
        amount: 30000,
        rootTransactionId: parentId,
        parentTransactionId: parentId,
      );
      await _post(
        database,
        purpose: BusinessPurpose.refund,
        amount: 20000,
        rootTransactionId: parentId,
        parentTransactionId: parentId,
        businessState: BusinessState.canceled,
      );

      final currentOnly = await repository.findChildren(
        parentId: parentId,
        states: {BusinessState.current},
      );
      expect(currentOnly.length, 1);
      expect(currentOnly.first.primaryAmount.minorUnits, 30000);

      final all = await repository.findChildren(parentId: parentId);
      expect(all.length, 2);
    });

    test(
      'watchPage 应用 scope.assetLiability(current only,不限 excluded)',
      () async {
        await _post(
          database,
          purpose: BusinessPurpose.dailyExpense,
          amount: 100000,
          occurredAt: DateTime(2026, 5, 10),
        );
        await _post(
          database,
          purpose: BusinessPurpose.dailyExpense,
          amount: 50000,
          occurredAt: DateTime(2026, 5, 11),
          isExcludedFromStats: true,
        );
        await _post(
          database,
          purpose: BusinessPurpose.dailyExpense,
          amount: 999,
          occurredAt: DateTime(2026, 5, 12),
          businessState: BusinessState.canceled,
        );

        final page =
            await repository.watchPage(const TransactionListQuery()).first;
        // 含 2 笔 current,不含 canceled
        expect(page.length, 2);
        expect(page.first.primaryAmount.minorUnits, 50000);

        final statsPage =
            await repository
                .watchPage(
                  const TransactionListQuery(
                    scope: TransactionScopeFilter.stats,
                  ),
                )
                .first;
        // 仅 stats=false 的 1 笔
        expect(statsPage.length, 1);
        expect(statsPage.first.primaryAmount.minorUnits, 100000);
      },
    );
  });
}

Future<int> _post(
  AppDatabase database, {
  required BusinessPurpose purpose,
  required int amount,
  DateTime? occurredAt,
  int? rootTransactionId,
  int? parentTransactionId,
  BusinessState businessState = BusinessState.current,
  bool isExcludedFromStats = false,
}) async {
  final transactionId = await database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          businessPurpose: purpose,
          occurredAt: occurredAt ?? DateTime(2026, 5, 1),
          primaryAmountMinor: amount,
          mutationKind: MutationKind.original,
          businessState: businessState,
          isExcludedFromStats: Value(isExcludedFromStats),
          sourceKind: SourceKind.manual,
          rootTransactionId: Value(rootTransactionId),
          parentTransactionId: Value(parentTransactionId),
        ),
      );

  if (rootTransactionId == null) {
    await (database.update(database.transactions)..where(
      (row) => row.id.equals(transactionId),
    )).write(TransactionsCompanion(rootTransactionId: Value(transactionId)));
  }

  return transactionId;
}
