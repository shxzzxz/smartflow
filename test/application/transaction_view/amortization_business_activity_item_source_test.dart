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
    when(() => service.findItemsForTransactions(any())).thenAnswer(
      (_) async => {
        'termination-recognition-tx': AmortizationBusinessActivityItemReadModel(
          planId: 'plan',
          itemKey: BusinessActivityItemKey(
            type: amortizationTerminationBusinessActivityItemType,
            id: 'termination',
          ),
          kind: AmortizationKind.prepaidExpense,
          role: BusinessActivityItemRole.followUp,
          terminationId: 'termination',
          projections: [
            AmortizationBusinessActivityItemProjection(
              planId: 'plan',
              transactionId: 'termination-recognition-tx',
              itemKey: BusinessActivityItemKey(
                type: amortizationTerminationBusinessActivityItemType,
                id: 'termination',
              ),
              kind: AmortizationKind.prepaidExpense,
              factKind: AmortizationTransactionFactKind.terminationRecognition,
              role: BusinessActivityItemRole.followUp,
              localCategoryAllocations: const [
                AccountAmountAllocation(
                  accountId: 'rent',
                  amount: Money(minorUnits: 1000),
                ),
              ],
              terminationId: 'termination',
            ),
            AmortizationBusinessActivityItemProjection(
              planId: 'plan',
              transactionId: 'termination-return-tx',
              itemKey: BusinessActivityItemKey(
                type: amortizationTerminationBusinessActivityItemType,
                id: 'termination',
              ),
              kind: AmortizationKind.prepaidExpense,
              factKind: AmortizationTransactionFactKind.terminationReturn,
              role: BusinessActivityItemRole.followUp,
              localCategoryAllocations: const [
                AccountAmountAllocation(
                  accountId: 'rent',
                  amount: Money(minorUnits: 500),
                ),
              ],
              terminationId: 'termination',
            ),
          ],
        ),
        'termination-return-tx': AmortizationBusinessActivityItemReadModel(
          planId: 'plan',
          itemKey: BusinessActivityItemKey(
            type: amortizationTerminationBusinessActivityItemType,
            id: 'termination',
          ),
          kind: AmortizationKind.prepaidExpense,
          role: BusinessActivityItemRole.followUp,
          terminationId: 'termination',
          projections: [
            AmortizationBusinessActivityItemProjection(
              planId: 'plan',
              transactionId: 'termination-recognition-tx',
              itemKey: BusinessActivityItemKey(
                type: amortizationTerminationBusinessActivityItemType,
                id: 'termination',
              ),
              kind: AmortizationKind.prepaidExpense,
              factKind: AmortizationTransactionFactKind.terminationRecognition,
              role: BusinessActivityItemRole.followUp,
              localCategoryAllocations: const [
                AccountAmountAllocation(
                  accountId: 'rent',
                  amount: Money(minorUnits: 1000),
                ),
              ],
              terminationId: 'termination',
            ),
            AmortizationBusinessActivityItemProjection(
              planId: 'plan',
              transactionId: 'termination-return-tx',
              itemKey: BusinessActivityItemKey(
                type: amortizationTerminationBusinessActivityItemType,
                id: 'termination',
              ),
              kind: AmortizationKind.prepaidExpense,
              factKind: AmortizationTransactionFactKind.terminationReturn,
              role: BusinessActivityItemRole.followUp,
              localCategoryAllocations: const [
                AccountAmountAllocation(
                  accountId: 'rent',
                  amount: Money(minorUnits: 500),
                ),
              ],
              terminationId: 'termination',
            ),
          ],
        ),
      },
    );
    final query = AmortizationBusinessActivityItemSource(service);

    final items = await query.findItems([
      _transaction('termination-recognition-tx'),
      _transaction('termination-return-tx'),
    ]);
    final recognitionItem =
        items['termination-recognition-tx']!
            as AmortizationBusinessActivityItem;
    final returnItem =
        items['termination-return-tx']! as AmortizationBusinessActivityItem;

    expect(recognitionItem.itemKey.id, 'termination');
    expect(returnItem.itemKey, recognitionItem.itemKey);
    expect(recognitionItem.role, BusinessActivityItemRole.followUp);
    expect(recognitionItem.activityKey.id, 'plan');
    expect(recognitionItem.projections, hasLength(2));
    final recognitionProjection =
        recognitionItem.projectionFor('termination-recognition-tx')!
            as AmortizationTransactionProjection;
    final returnProjection =
        returnItem.projectionFor('termination-return-tx')!
            as AmortizationTransactionProjection;
    expect(
      recognitionProjection.factKind,
      AmortizationTransactionFactKind.terminationRecognition,
    );
    expect(
      returnProjection.factKind,
      AmortizationTransactionFactKind.terminationReturn,
    );
    expect(
      recognitionProjection.localCategoryAllocations.single.amount.minorUnits,
      1000,
    );
    expect(
      returnProjection.localCategoryAllocations.single.amount.minorUnits,
      500,
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
