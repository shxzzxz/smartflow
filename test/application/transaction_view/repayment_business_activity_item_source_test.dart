import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/business_activity_item/source/repayment_business_activity_item_source.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';

class _MockCreditBusinessActivityQueryService extends Mock
    implements CreditBusinessActivityQueryService {}

void main() {
  test('maps origin and follow-up repayment-owned facts', () async {
    final query = _MockCreditBusinessActivityQueryService();
    when(
      () => query.findRepaymentSummaries({'bill-repayment', 'prepayment'}),
    ).thenAnswer(
      (_) async => {
        'bill-repayment': CreditRepaymentBusinessActivitySummary.fromRepayment(
          repaymentId: 'bill-repayment',
          repaymentType: RepaymentType.bill,
          targetType: RepaymentTargetType.bill,
          targetId: 'bill-1',
        ),
        'prepayment': CreditRepaymentBusinessActivitySummary.fromRepayment(
          repaymentId: 'prepayment',
          repaymentType: RepaymentType.prepayment,
          targetType: RepaymentTargetType.contract,
          targetId: 'contract-1',
        ),
      },
    );
    final source = RepaymentBusinessActivityItemSource(query);

    final items = await source.findItems([
      _transaction(id: 'bill-tx', repaymentId: 'bill-repayment'),
      _transaction(id: 'prepayment-tx', repaymentId: 'prepayment'),
    ]);
    final bill = items['bill-tx']! as RepaymentBusinessActivityItem;
    final prepayment = items['prepayment-tx']! as RepaymentBusinessActivityItem;

    expect(bill.role, BusinessActivityItemRole.origin);
    expect(
      bill.itemKey,
      const BusinessActivityItemKey(
        type: creditRepaymentOwnerType,
        id: 'bill-repayment',
      ),
    );
    expect(
      bill.activityKey,
      const BusinessActivityKey(
        type: creditRepaymentOwnerType,
        id: 'bill-repayment',
      ),
    );
    expect(bill.repaymentType, RepaymentType.bill);
    expect(bill.repaymentId, 'bill-repayment');
    expect(bill.targetId, 'bill-1');

    expect(prepayment.role, BusinessActivityItemRole.followUp);
    expect(
      prepayment.itemKey,
      const BusinessActivityItemKey(
        type: creditRepaymentOwnerType,
        id: 'prepayment',
      ),
    );
    expect(
      prepayment.activityKey,
      const BusinessActivityKey(type: installmentOwnerType, id: 'contract-1'),
    );
    expect(prepayment.repaymentType, RepaymentType.prepayment);
    expect(prepayment.repaymentId, 'prepayment');
    expect(prepayment.targetId, 'contract-1');
    expect(bill.projections.single.transactionId, 'bill-tx');
    expect(prepayment.projections.single.transactionId, 'prepayment-tx');
  });
}

TransactionReadModel _transaction({
  required String id,
  required String repaymentId,
}) {
  return TransactionReadModel(
    id: id,
    businessPurpose: BusinessPurpose.debtRepayment,
    occurredAt: DateTime(2026, 1, 15),
    primaryAmount: const Money(minorUnits: 1200),
    ownership: TransactionOwnership(
      ownerType: creditRepaymentOwnerType,
      ownerId: repaymentId,
    ),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
