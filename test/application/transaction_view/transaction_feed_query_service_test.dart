import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

class _MockTransactionQueryService extends Mock
    implements TransactionQueryService {}

class _MockBusinessActivityItemQuery extends Mock
    implements BusinessActivityItemQuery {}

void main() {
  test('composes ledger transactions with batched business items', () async {
    final transactions = _MockTransactionQueryService();
    final items = _MockBusinessActivityItemQuery();
    final amortization = _transaction(
      'recognition',
      ownerType: orchestrationAmortizationOwnerType,
    );
    final ordinary = _transaction('ordinary');
    const query = TransactionListQuery();
    when(
      () => transactions.findTransactions(query),
    ).thenAnswer((_) async => [amortization, ordinary]);
    when(() => items.findItems(any())).thenAnswer(
      (_) async => {
        'recognition': AmortizationBusinessActivityItem(
          activityKey: const BusinessActivityKey(
            type: orchestrationAmortizationOwnerType,
            id: 'plan',
          ),
          itemKey: BusinessActivityItemKey.transaction('recognition'),
          role: BusinessActivityItemRole.followUp,
          occurredAt: amortization.occurredAt,
          projections: [
            AmortizationTransactionProjection(
              transactionId: 'recognition',
              factKind: AmortizationTransactionFactKind.recognition,
              localCategoryAllocations: const [
                AccountAmountAllocation(
                  accountId: 'membership',
                  amount: Money(minorUnits: 100),
                ),
              ],
            ),
          ],
          kind: AmortizationKind.prepaidExpense,
        ),
      },
    );
    final service = TransactionFeedQueryServiceImpl(
      transactions: transactions,
      businessItems: items,
    );

    final entries = await service.findTransactions(query);

    expect(entries.map((entry) => entry.transaction.id), [
      'recognition',
      'ordinary',
    ]);
    expect(entries.first.businessItem, isNotNull);
    expect(entries.first.transactionProjection!.transactionId, 'recognition');
    expect(entries.last.businessItem, isNull);
  });

  test(
    'watches the current transaction set with bounded business items',
    () async {
      final transactions = _MockTransactionQueryService();
      final items = _MockBusinessActivityItemQuery();
      final transaction = _transaction(
        'recognition',
        ownerType: orchestrationAmortizationOwnerType,
      );
      const query = TransactionListQuery();
      final item = AmortizationBusinessActivityItem(
        activityKey: const BusinessActivityKey(
          type: orchestrationAmortizationOwnerType,
          id: 'plan',
        ),
        itemKey: BusinessActivityItemKey.transaction(transaction.id),
        role: BusinessActivityItemRole.followUp,
        occurredAt: transaction.occurredAt,
        projections: [
          AmortizationTransactionProjection(
            transactionId: transaction.id,
            factKind: AmortizationTransactionFactKind.recognition,
            localCategoryAllocations: const [],
          ),
        ],
        kind: AmortizationKind.prepaidExpense,
      );
      when(
        () => transactions.watchTransactions(query),
      ).thenAnswer((_) => Stream.value([transaction]));
      when(
        () => items.watchItems(any()),
      ).thenAnswer((_) => Stream.value({transaction.id: item}));
      final service = TransactionFeedQueryServiceImpl(
        transactions: transactions,
        businessItems: items,
      );

      final entries = await service.watchTransactions(query).first;

      expect(entries.single.businessItem, same(item));
      expect(entries.single.transactionProjection, item.projections.single);
      verify(() => items.watchItems(any())).called(1);
    },
  );
}

TransactionReadModel _transaction(String id, {String? ownerType}) {
  return TransactionReadModel(
    id: id,
    businessPurpose: BusinessPurpose.dailyExpense,
    occurredAt: DateTime(2026, 1),
    primaryAmount: const Money(minorUnits: 100),
    ownership: ownerType == null
        ? null
        : TransactionOwnership(ownerType: ownerType, ownerId: 'plan'),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
