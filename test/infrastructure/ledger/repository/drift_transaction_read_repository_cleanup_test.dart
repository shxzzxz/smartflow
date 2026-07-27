import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/entry.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  late AppDatabase database;
  late DriftTransactionReadRepository repository;

  setUp(() async {
    database = createTestDatabase();
    repository = DriftTransactionReadRepository(database);
    final posting = DriftPostingRepository(database);
    await posting.saveAll([
      _transaction(
        id: 'food-cash',
        occurredAt: DateTime(2026, 6, 15),
        debitAccountId: 'cat-food',
        creditAccountId: 'acc-cash',
      ),
      _transaction(
        id: 'food-bank',
        occurredAt: DateTime(2026, 7, 10),
        debitAccountId: 'cat-food',
        creditAccountId: 'acc-bank',
      ),
      // food-bank 的退款子交易，分录触达 acc-cash。
      _transaction(
        id: 'food-bank-refund',
        parentId: 'food-bank',
        occurredAt: DateTime(2026, 7, 11),
        debitAccountId: 'acc-cash',
        creditAccountId: 'cat-food',
      ),
      _transaction(
        id: 'travel-cash',
        occurredAt: DateTime(2026, 7, 20),
        debitAccountId: 'cat-travel',
        creditAccountId: 'acc-cash',
      ),
      _transaction(
        id: 'repayment-owned',
        occurredAt: DateTime(2026, 7, 5),
        debitAccountId: 'acc-liability',
        creditAccountId: 'acc-cash',
        ownership: const TransactionOwnership(
          ownerType: 'credit_repayment',
          ownerId: 'repayment-1',
        ),
      ),
      _transaction(
        id: 'parent-of-owned-child',
        occurredAt: DateTime(2026, 7, 12),
        debitAccountId: 'cat-food',
        creditAccountId: 'acc-cash',
      ),
      _transaction(
        id: 'owned-child',
        parentId: 'parent-of-owned-child',
        occurredAt: DateTime(2026, 7, 12),
        debitAccountId: 'acc-cash',
        creditAccountId: 'cat-food',
        ownership: const TransactionOwnership(ownerType: 'installment'),
      ),
    ]);
  });

  tearDown(() async {
    await database.close();
  });

  test('无条件时匹配全部顶层交易组并标记业务归属', () async {
    final targets = await repository.findCleanupTargets(
      const TransactionCleanupQuery(),
    );

    expect(targets, hasLength(5));
    final ownedById = {
      for (final target in targets) target.transactionId: target.owned,
    };
    expect(ownedById, {
      'food-cash': false,
      'food-bank': false,
      'travel-cash': false,
      'repayment-owned': true,
      'parent-of-owned-child': true,
    });
  });

  test('分类与账户条件取交集，且只按顶层交易自身分录匹配', () async {
    final targets = await repository.findCleanupTargets(
      const TransactionCleanupQuery(
        categoryIds: {'cat-food'},
        accountIds: {'acc-cash'},
      ),
    );

    // food-bank 仅子交易触达 acc-cash，不应命中。
    expect(
      targets.map((target) => target.transactionId),
      unorderedEquals(['food-cash', 'parent-of-owned-child']),
    );
  });

  test('时间范围含起点、不含终点', () async {
    final fromBoundary = await repository.findCleanupTargets(
      TransactionCleanupQuery(
        occurredFrom: DateTime(2026, 6, 15),
        occurredUntil: DateTime(2026, 7, 1),
      ),
    );
    expect(
      fromBoundary.map((target) => target.transactionId),
      ['food-cash'],
    );

    final untilBoundary = await repository.findCleanupTargets(
      TransactionCleanupQuery(
        occurredFrom: DateTime(2026, 6, 1),
        occurredUntil: DateTime(2026, 6, 15),
      ),
    );
    expect(untilBoundary, isEmpty);
  });

  test('预览统计命中总数与业务归属数量', () async {
    final preview =
        await repository
            .watchCleanupPreview(const TransactionCleanupQuery())
            .first;

    expect(preview.matchedGroupCount, 5);
    expect(preview.ownedGroupCount, 2);
    expect(preview.deletableGroupCount, 3);

    final scoped =
        await repository
            .watchCleanupPreview(
              const TransactionCleanupQuery(accountIds: {'acc-bank'}),
            )
            .first;
    expect(scoped.matchedGroupCount, 1);
    expect(scoped.ownedGroupCount, 0);
  });
}

Transaction _transaction({
  required String id,
  required DateTime occurredAt,
  required String debitAccountId,
  required String creditAccountId,
  String? parentId,
  TransactionOwnership? ownership,
}) {
  const amount = Money(minorUnits: 1000);
  return Transaction(
    id: id,
    businessPurpose:
        parentId == null
            ? BusinessPurpose.dailyExpense
            : BusinessPurpose.refund,
    occurredAt: occurredAt,
    primaryAmount: amount,
    parentTransactionId: parentId,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    sourceKind: SourceKind.manual,
    ownership: ownership,
    entries: [
      Entry(
        id: 'entry-$id-debit',
        transactionId: id,
        accountId: debitAccountId,
        direction: EntryDirection.debit,
        amount: amount,
      ),
      Entry(
        id: 'entry-$id-credit',
        transactionId: id,
        accountId: creditAccountId,
        direction: EntryDirection.credit,
        amount: amount,
      ),
    ],
  );
}
