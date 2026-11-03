import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/orchestration/amortization/query/amortization_plan_query_service.dart';
import 'package:smartflow/application/orchestration/amortization/query/amortization_transaction_context_query.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_refund.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_termination.dart';
import 'package:smartflow/domain/orchestration/port/amortization_repository.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

void main() {
  test('projects only requested amortization transactions', () async {
    final plan = _planWithRefundAndTermination();
    final repository = _FakeAmortizationRepository([plan]);
    final query = AmortizationTransactionContextQueryService(
      AmortizationPlanQueryService(repository),
    );

    final contexts = await query.findForTransactions({
      plan.id: {'refund-tx', 'termination-tx', 'unrelated-tx'},
    });

    expect(contexts.keys, containsAll(['refund-tx', 'termination-tx']));
    expect(contexts.keys, isNot(contains('unrelated-tx')));
    expect(
      contexts['refund-tx']!.factKind,
      AmortizationTransactionFactKind.refund,
    );
    expect(contexts['refund-tx']!.refundId, 'refund');
    expect(
      contexts['termination-tx']!.factKind,
      AmortizationTransactionFactKind.terminationRecognition,
    );
    expect(contexts['termination-tx']!.terminationId, 'termination');
  });
}

AmortizationPlan _planWithRefundAndTermination() {
  final created = AmortizationPlan.create(
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
    initialTransactionId: 'initial-tx',
  );
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
  return refunded.terminatedWith(
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
}

final class _FakeAmortizationRepository implements AmortizationRepository {
  _FakeAmortizationRepository(this.plans);

  final List<AmortizationPlan> plans;

  @override
  Future<AmortizationPlan?> findById(String id) async =>
      plans.where((plan) => plan.id == id).firstOrNull;

  @override
  Future<List<AmortizationPlan>> findByIds(Set<String> ids) async => [
    for (final plan in plans)
      if (ids.contains(plan.id)) plan,
  ];

  @override
  Future<List<AmortizationPlan>> findAll({String? deferralAccountId}) async =>
      plans;

  @override
  Stream<List<AmortizationPlan>> watchAll({String? deferralAccountId}) =>
      Stream.value(plans);

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<void> save(AmortizationPlan plan) async {}
}
