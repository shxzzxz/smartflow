import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/amortization/query/amortization_business_activity_item_query.dart';
import 'package:smartflow/application/transaction_view/business_activity_item/source/amortization_business_activity_item_source.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

class _MockAmortizationBusinessActivityItemQueryService extends Mock
    implements AmortizationBusinessActivityItemQueryService {}

void main() {
  test('maps local amortization facts to the activity item', () async {
    final service = _MockAmortizationBusinessActivityItemQueryService();
    when(() => service.findForTransactions(any())).thenAnswer(
      (_) async => {
        'refund-tx': AmortizationBusinessActivityItemProjection(
          planId: 'plan',
          transactionId: 'refund-tx',
          kind: AmortizationKind.prepaidExpense,
          factKind: AmortizationTransactionFactKind.refund,
          localCategoryAllocations: const [
            AccountAmountAllocation(
              accountId: 'rent',
              amount: Money(minorUnits: 1000),
            ),
          ],
          refundId: 'refund',
        ),
      },
    );
    final query = AmortizationBusinessActivityItemSource(service);

    final refundItem = (await query.findItems([
      _transaction('refund-tx'),
    ]))['refund-tx'];

    expect(
      (refundItem! as AmortizationBusinessActivityItem).factKind,
      AmortizationTransactionFactKind.refund,
    );
    expect((refundItem as AmortizationBusinessActivityItem).refundId, 'refund');
    expect(refundItem.localCategoryAllocations.single.amount.minorUnits, 1000);
  });
}

TransactionReadModel _transaction(String id) {
  return TransactionReadModel(
    id: id,
    businessPurpose: BusinessPurpose.transfer,
    occurredAt: DateTime(2026, 1, 15),
    primaryAmount: const Money(minorUnits: 10000),
    ownership: const TransactionOwnership(
      ownerType: orchestrationAmortizationOwnerType,
      ownerId: 'plan',
    ),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
