import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/amortization/query/amortization_transaction_context_query.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/application/transaction_view/business_context/source/amortization_business_context_source.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

class _MockAmortizationTransactionContextQueryService extends Mock
    implements AmortizationTransactionContextQueryService {}

void main() {
  test('maps amortization domain context to the detail projection', () async {
    final service = _MockAmortizationTransactionContextQueryService();
    when(() => service.findForTransactions(any())).thenAnswer(
      (_) async => {
        'refund-tx': const AmortizationTransactionContext(
          planId: 'plan',
          transactionId: 'refund-tx',
          initialTransactionId: 'initial',
          kind: AmortizationKind.prepaidExpense,
          status: AmortizationStatus.active,
          originalAmount: Money(minorUnits: 30000),
          recognizedAmount: Money(minorUnits: 0),
          remainingAmount: Money(minorUnits: 29000),
          postedPeriodCount: 0,
          totalPeriodCount: 3,
          categoryAccountIds: ['rent'],
          factKind: AmortizationTransactionFactKind.refund,
          refundId: 'refund',
        ),
      },
    );
    final query = AmortizationBusinessContextSource(service);

    final refundOwner = (await query.findContexts([
      _transaction('refund-tx'),
    ]))['refund-tx'];

    expect(
      (refundOwner! as AmortizationTransactionDetailOwnerContext).factKind,
      AmortizationTransactionFactKind.refund,
    );
    expect(
      (refundOwner as AmortizationTransactionDetailOwnerContext).refundId,
      'refund',
    );
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
