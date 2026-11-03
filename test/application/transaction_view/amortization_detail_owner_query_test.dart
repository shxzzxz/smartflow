import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/amortization/query/amortization_plan_query_service.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_detail/source/amortization_detail_owner_query.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_refund.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_termination.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

class _MockAmortizationPlanQueryService extends Mock
    implements AmortizationPlanQueryService {}

void main() {
  test('classifies amortization refund and termination transactions', () async {
    final service = _MockAmortizationPlanQueryService();
    final created = _plan();
    final refunded = created.withRefund(
      AmortizationRefund(
        id: 'refund',
        planId: created.id,
        categoryAllocations: singleAllocation(
          accountId: 'rent',
          amount: const Money(minorUnits: 1000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: const Money(minorUnits: 1000),
        ),
        transferTransactionId: 'refund-tx',
      ),
    );
    final plan = refunded.terminatedWith(
      termination: AmortizationTermination(
        id: 'termination',
        planId: created.id,
        terminatedAt: DateTime(2026, 2, 1),
        categoryReturnAllocations: const [],
        settlementAllocations: const [],
        recognitionTransactionId: 'termination-tx',
      ),
      periods: refunded.periods,
    );
    when(() => service.findById('plan')).thenAnswer((_) async => plan);
    final query = AmortizationDetailOwnerQuery(service);
    const ownership = TransactionOwnership(
      ownerType: orchestrationAmortizationOwnerType,
      ownerId: 'plan',
    );

    final refundOwner = await query.find(ownership, _transaction('refund-tx'));
    final terminationOwner = await query.find(
      ownership,
      _transaction('termination-tx'),
    );

    expect(
      (refundOwner! as AmortizationTransactionDetailOwnerContext).factKind,
      AmortizationTransactionFactKind.refund,
    );
    expect(
      (refundOwner as AmortizationTransactionDetailOwnerContext).refundId,
      'refund',
    );
    expect(
      (terminationOwner! as AmortizationTransactionDetailOwnerContext).factKind,
      AmortizationTransactionFactKind.terminationRecognition,
    );
  });
}

AmortizationPlan _plan() {
  return AmortizationPlan.create(
    id: 'plan',
    kind: AmortizationKind.prepaidExpense,
    deferralAccountId: 'prepaid',
    fundingAllocations: singleAllocation(
      accountId: 'cash',
      amount: const Money(minorUnits: 30000),
    ),
    categoryAllocations: singleAllocation(
      accountId: 'rent',
      amount: const Money(minorUnits: 30000),
    ),
    originalAmount: const Money(minorUnits: 30000),
    cadenceUnit: AmortizationCadenceUnit.monthly,
    cadenceInterval: 1,
    firstRecognitionAt: DateTime(2026, 1, 31),
    recognitionCount: 3,
    initialTransactionId: 'initial',
  );
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
