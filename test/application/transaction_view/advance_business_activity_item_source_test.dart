import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/advance/query/advance_business_activity_item_query.dart';
import 'package:smartflow/application/orchestration/advance/query/advance_case_query_service.dart';
import 'package:smartflow/application/transaction_view/business_activity_item/source/advance_business_activity_item_source.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

class _MockAdvanceCaseQueryService extends Mock
    implements AdvanceCaseQueryService {}

void main() {
  test('child transaction is classified without anchor summary', () async {
    final cases = _MockAdvanceCaseQueryService();
    when(() => cases.findBusinessActivityItems(any())).thenAnswer(
      (_) async => {
        'refund-1': const AdvanceBusinessActivityItemProjection(
          transactionId: 'refund-1',
          advanceCaseId: 'advance-1',
          factKind: AdvanceTransactionFactKind.refund,
          role: BusinessActivityItemRole.followUp,
          scenario: AdvanceScenario.reimbursement,
          trackingMode: AdvanceTrackingMode.itemized,
        ),
      },
    );
    final source = AdvanceBusinessActivityItemSource(cases);

    final item =
        (await source.findItems([_childTransaction()]))['refund-1']
            as AdvanceBusinessActivityItem;

    expect(item.factKind, AdvanceTransactionFactKind.refund);
    expect(item.role, BusinessActivityItemRole.followUp);
    expect(item.scenario, AdvanceScenario.reimbursement);
    expect(item.trackingMode, AdvanceTrackingMode.itemized);
  });
}

TransactionReadModel _childTransaction() {
  return TransactionReadModel(
    id: 'refund-1',
    parentTransactionId: 'advance-tx',
    businessPurpose: BusinessPurpose.refund,
    occurredAt: DateTime(2026, 1, 2),
    primaryAmount: const Money(minorUnits: 1000),
    ownership: const TransactionOwnership(
      ownerType: orchestrationAdvanceOwnerType,
      ownerId: 'advance-1',
    ),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
