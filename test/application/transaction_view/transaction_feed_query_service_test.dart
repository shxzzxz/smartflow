import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

class _MockTransactionQueryService extends Mock
    implements TransactionQueryService {}

class _MockBusinessContextQuery extends Mock
    implements TransactionBusinessContextQuery {}

void main() {
  test('composes ledger transactions with batched business context', () async {
    final transactions = _MockTransactionQueryService();
    final contexts = _MockBusinessContextQuery();
    final amortization = _transaction(
      'recognition',
      ownerType: orchestrationAmortizationOwnerType,
    );
    final ordinary = _transaction('ordinary');
    const query = TransactionListQuery();
    when(
      () => transactions.findTransactions(query),
    ).thenAnswer((_) async => [amortization, ordinary]);
    when(() => contexts.findContexts(any())).thenAnswer(
      (_) async => {
        'recognition': const AmortizationTransactionBusinessContext(
          ownerType: orchestrationAmortizationOwnerType,
          ownerId: 'plan',
          initialTransactionId: 'initial',
          kind: AmortizationKind.prepaidExpense,
          status: AmortizationStatus.active,
          originalAmount: Money(minorUnits: 1200),
          recognizedAmount: Money(minorUnits: 100),
          remainingAmount: Money(minorUnits: 1100),
          postedPeriodCount: 1,
          totalPeriodCount: 12,
          categoryAccountIds: ['membership'],
          factKind: AmortizationTransactionFactKind.recognition,
        ),
      },
    );
    final service = TransactionFeedQueryServiceImpl(
      transactions: transactions,
      businessContexts: contexts,
    );

    final entries = await service.findTransactions(query);

    expect(entries.map((entry) => entry.transaction.id), [
      'recognition',
      'ordinary',
    ]);
    expect(entries.first.businessContext, isNotNull);
    expect(entries.last.businessContext, isNull);
  });
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
