import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/business_activity_item/source/installment_business_activity_item_source.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';

class _MockInstallmentQueryService extends Mock
    implements InstallmentQueryService {}

void main() {
  test('maps credit-owned installment fact kinds', () async {
    final query = _MockInstallmentQueryService();
    final transaction = _transaction(BusinessPurpose.refund);
    when(() => query.findBusinessActivityItems(any())).thenAnswer(
      (_) async => {
        'tx-1': const InstallmentBusinessActivityItemProjection(
          transactionId: 'tx-1',
          installmentId: 'contract-1',
          itemKey: BusinessActivityItemKey.transaction('tx-1'),
          installmentType: InstallmentType.purchase,
          factKind: InstallmentTransactionFactKind.refund,
          role: BusinessActivityItemRole.followUp,
        ),
      },
    );
    final source = InstallmentBusinessActivityItemSource(query);

    final item =
        (await source.findItems([transaction]))['tx-1']
            as InstallmentBusinessActivityItem;

    expect(item.factKind, InstallmentTransactionFactKind.refund);
    expect(item.role, BusinessActivityItemRole.followUp);
    expect(item.itemKey, const BusinessActivityItemKey.transaction('tx-1'));
    expect(item.activityKey.id, 'contract-1');
    expect(item.projections.single.transactionId, 'tx-1');
    expect(item.installmentType, InstallmentType.purchase);
  });
}

TransactionReadModel _transaction(BusinessPurpose purpose) {
  return TransactionReadModel(
    id: 'tx-1',
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 1, 15),
    primaryAmount: const Money(minorUnits: 1200),
    ownership: const TransactionOwnership(
      ownerType: installmentOwnerType,
      ownerId: 'contract-1',
    ),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
