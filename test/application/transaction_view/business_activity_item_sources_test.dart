import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/advance/query/advance_business_activity_item_query.dart';
import 'package:smartflow/application/orchestration/advance/query/advance_case_query_service.dart';
import 'package:smartflow/application/orchestration/amortization/query/amortization_business_activity_item_query.dart';
import 'package:smartflow/application/transaction_view/business_activity_item/source/advance_business_activity_item_source.dart';
import 'package:smartflow/application/transaction_view/business_activity_item/source/amortization_business_activity_item_source.dart';
import 'package:smartflow/application/transaction_view/business_activity_item/source/installment_business_activity_item_source.dart';
import 'package:smartflow/application/transaction_view/business_activity_item/source/repayment_business_activity_item_source.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

class _MockAdvanceCaseQueryService extends Mock
    implements AdvanceCaseQueryService {}

class _MockAmortizationBusinessActivityItemQueryService extends Mock
    implements AmortizationBusinessActivityItemQueryService {}

class _MockInstallmentQueryService extends Mock
    implements InstallmentQueryService {}

class _MockCreditBusinessActivityQueryService extends Mock
    implements CreditBusinessActivityQueryService {}

void main() {
  group('AdvanceBusinessActivityItemSource', () {
    test('child transaction is classified without anchor summary', () async {
      final cases = _MockAdvanceCaseQueryService();
      when(() => cases.findBusinessActivityItems(any())).thenAnswer(
        (_) async => {
          'refund-1': const AdvanceBusinessActivityItemProjection(
            transactionId: 'refund-1',
            advanceCaseId: 'advance-1',
            itemKey: BusinessActivityItemKey.transaction('refund-1'),
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
      expect(
        item.itemKey,
        const BusinessActivityItemKey.transaction('refund-1'),
      );
      expect(item.activityKey.id, 'advance-1');
      expect(item.projections.single.transactionId, 'refund-1');
      expect(item.occurredAt, DateTime(2026, 1, 2));
      expect(item.scenario, AdvanceScenario.reimbursement);
      expect(item.trackingMode, AdvanceTrackingMode.itemized);
    });
  });

  group('AmortizationBusinessActivityItemSource', () {
    test('maps local amortization facts to the activity item', () async {
      final service = _MockAmortizationBusinessActivityItemQueryService();
      when(() => service.findItemsForTransactions(any())).thenAnswer(
        (_) async => {
          'termination-recognition-tx':
              AmortizationBusinessActivityItemReadModel(
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
                    factKind:
                        AmortizationTransactionFactKind.terminationRecognition,
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
                factKind:
                    AmortizationTransactionFactKind.terminationRecognition,
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
        _amortizationTransaction('termination-recognition-tx'),
        _amortizationTransaction('termination-return-tx'),
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
  });

  group('InstallmentBusinessActivityItemSource', () {
    test('maps credit-owned installment fact kinds', () async {
      final query = _MockInstallmentQueryService();
      final transaction = _installmentTransaction(BusinessPurpose.refund);
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
  });

  group('RepaymentBusinessActivityItemSource', () {
    test('maps origin and follow-up repayment-owned facts', () async {
      final query = _MockCreditBusinessActivityQueryService();
      when(
        () => query.findRepaymentSummaries({'bill-repayment', 'prepayment'}),
      ).thenAnswer(
        (_) async => {
          'bill-repayment':
              CreditRepaymentBusinessActivitySummary.fromRepayment(
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
        _repaymentTransaction(id: 'bill-tx', repaymentId: 'bill-repayment'),
        _repaymentTransaction(id: 'prepayment-tx', repaymentId: 'prepayment'),
      ]);
      final bill = items['bill-tx']! as RepaymentBusinessActivityItem;
      final prepayment =
          items['prepayment-tx']! as RepaymentBusinessActivityItem;

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

TransactionReadModel _amortizationTransaction(String id) {
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

TransactionReadModel _installmentTransaction(BusinessPurpose purpose) {
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

TransactionReadModel _repaymentTransaction({
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
