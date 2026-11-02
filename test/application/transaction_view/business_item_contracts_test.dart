import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';

void main() {
  group('BusinessItemPageQuery', () {
    test('freezes filter sets and carries the exclusive time window', () {
      final categories = {'food'};
      final settlements = {'cash'};
      final tags = {'travel'};
      final from = DateTime(2026, 10);
      final until = DateTime(2026, 11);

      final query = BusinessItemPageQuery(
        occurredFrom: from,
        occurredUntil: until,
        categoryAccountIds: categories,
        settlementAccountIds: settlements,
        tagIds: tags,
        limit: 30,
      );

      categories.add('housing');
      settlements.add('credit');
      tags.add('work');

      expect(query.occurredFrom, from);
      expect(query.occurredUntil, until);
      expect(query.categoryAccountIds, {'food'});
      expect(query.settlementAccountIds, {'cash'});
      expect(query.tagIds, {'travel'});
      expect(query.limit, 30);
    });

    test('requires a positive, ordered time window', () {
      expect(
        () => BusinessItemPageQuery(
          occurredFrom: DateTime(2026, 11),
          occurredUntil: DateTime(2026, 11),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('BusinessItemReadModel', () {
    test('derives anchor identity and time from the loaded transaction', () {
      final occurredAt = DateTime(2026, 10, 12, 9, 30);
      final transaction = _transaction(
        id: 'tx-anchor',
        occurredAt: occurredAt,
        ownership: const TransactionOwnership(
          ownerType: 'orchestration.amortization',
          ownerId: 'plan-1',
        ),
      );
      final item = BusinessItemReadModel.fromCandidate(
        candidate: BusinessItemAnchorCandidate(
          itemKey: const BusinessItemKey(
            type: 'orchestration.amortization',
            id: 'plan-1',
          ),
          anchorTransactionId: 'tx-anchor',
          anchorAt: occurredAt,
        ),
        anchorTransaction: transaction,
        summary: const LedgerBusinessItemSummary(),
      );

      expect(item.anchorTransactionId, 'tx-anchor');
      expect(item.anchorAt, occurredAt);
      expect(item.ownerType, 'orchestration.amortization');
      expect(item.ownerId, 'plan-1');
    });

    test('rejects an anchor whose occurredAt differs from anchorAt', () {
      final transaction = _transaction(
        id: 'tx-anchor',
        occurredAt: DateTime(2026, 10, 12),
      );

      expect(
        () => BusinessItemReadModel.fromCandidate(
          candidate: BusinessItemAnchorCandidate(
            itemKey: const BusinessItemKey.transactionGroup('tx-anchor'),
            anchorTransactionId: 'tx-anchor',
            anchorAt: DateTime(2026, 10, 13),
          ),
          anchorTransaction: transaction,
          summary: const LedgerBusinessItemSummary(),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a child transaction as an item anchor', () {
      final occurredAt = DateTime(2026, 10, 12);
      final transaction = _transaction(
        id: 'tx-child',
        occurredAt: occurredAt,
        parentTransactionId: 'tx-parent',
      );

      expect(
        () => BusinessItemReadModel.fromCandidate(
          candidate: BusinessItemAnchorCandidate(
            itemKey: const BusinessItemKey.transactionGroup('tx-parent'),
            anchorTransactionId: 'tx-child',
            anchorAt: occurredAt,
          ),
          anchorTransaction: transaction,
          summary: const LedgerBusinessItemSummary(),
        ),
        throwsArgumentError,
      );
    });
  });

  test('BusinessItemPage returns a cursor only when another page exists', () {
    final occurredAt = DateTime(2026, 10, 12);
    final item = BusinessItemReadModel.fromCandidate(
      candidate: BusinessItemAnchorCandidate(
        itemKey: const BusinessItemKey.transactionGroup('tx-1'),
        anchorTransactionId: 'tx-1',
        anchorAt: occurredAt,
      ),
      anchorTransaction: _transaction(id: 'tx-1', occurredAt: occurredAt),
      summary: const LedgerBusinessItemSummary(),
    );

    expect(BusinessItemPage(items: [item], hasMore: false).nextCursor, isNull);
    expect(
      BusinessItemPage(items: [item], hasMore: true).nextCursor?.itemKey,
      const BusinessItemKey.transactionGroup('tx-1'),
    );
  });
}

TransactionReadModel _transaction({
  required String id,
  required DateTime occurredAt,
  String? parentTransactionId,
  TransactionOwnership? ownership,
}) {
  return TransactionReadModel(
    id: id,
    parentTransactionId: parentTransactionId,
    businessPurpose: BusinessPurpose.dailyExpense,
    occurredAt: occurredAt,
    primaryAmount: Money(minorUnits: 100),
    ownership: ownership,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
