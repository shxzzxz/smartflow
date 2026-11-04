import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/business_activity_item/source/repayment_business_activity_item_source.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';

class _MockCreditTransactionViewQueryService extends Mock
    implements CreditTransactionViewQueryService {}

void main() {
  test('maps repayment-owned facts', () async {
    final query = _MockCreditTransactionViewQueryService();
    when(() => query.findRepaymentSummaries({'repayment-1'})).thenAnswer(
      (_) async => {
        'repayment-1': const CreditRepaymentBusinessActivitySummary(
          repaymentType: RepaymentType.bill,
          targetType: RepaymentTargetType.bill,
          targetId: 'bill-1',
        ),
      },
    );
    final source = RepaymentBusinessActivityItemSource(query);

    final item =
        (await source.findItems([_transaction()]))['tx-1']
            as RepaymentBusinessActivityItem;

    expect(item.repaymentType, RepaymentType.bill);
    expect(item.targetId, 'bill-1');
  });
}

TransactionReadModel _transaction() {
  return TransactionReadModel(
    id: 'tx-1',
    businessPurpose: BusinessPurpose.debtRepayment,
    occurredAt: DateTime(2026, 1, 15),
    primaryAmount: const Money(minorUnits: 1200),
    ownership: const TransactionOwnership(
      ownerType: creditRepaymentOwnerType,
      ownerId: 'repayment-1',
    ),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
