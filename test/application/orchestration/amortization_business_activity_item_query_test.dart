import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/orchestration/amortization/query/amortization_plan_query_service.dart';
import 'package:smartflow/application/orchestration/amortization/query/amortization_business_activity_item_query.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_refund.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_termination.dart';
import 'package:smartflow/domain/orchestration/port/amortization_repository.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/shared/business_activity/business_activity_item_role.dart';

void main() {
  test('projects only requested amortization transactions', () async {
    final plan = _planWithRefundAndTermination();
    final repository = _FakeAmortizationRepository([plan]);
    final query = AmortizationBusinessActivityItemQueryService(
      AmortizationPlanQueryService(repository),
    );

    final items = await query.findForTransactions({
      plan.id: {'refund-tx', 'termination-tx', 'unrelated-tx'},
    });

    expect(items.keys, containsAll(['refund-tx', 'termination-tx']));
    expect(items.keys, isNot(contains('unrelated-tx')));
    expect(
      items['refund-tx']!.factKind,
      AmortizationTransactionFactKind.refund,
    );
    expect(items['refund-tx']!.role, BusinessActivityItemRole.followUp);
    expect(items['refund-tx']!.refundId, 'refund');
    expect(
      items['refund-tx']!.localCategoryAllocations.single.amount,
      const Money(minorUnits: 1000),
    );
    expect(
      items['termination-tx']!.factKind,
      AmortizationTransactionFactKind.terminationRecognition,
    );
    expect(items['termination-tx']!.role, BusinessActivityItemRole.followUp);
    expect(items['termination-tx']!.terminationId, 'termination');
  });

  test('watch requests only the current plan IDs', () async {
    final plan = _planWithRefundAndTermination();
    final repository = _FakeAmortizationRepository([plan]);
    final query = AmortizationBusinessActivityItemQueryService(
      AmortizationPlanQueryService(repository),
    );

    await query.watchForTransactions({
      plan.id: {'refund-tx'},
    }).first;

    expect(repository.lastWatchIds, {plan.id});
  });

  test('watch does not emit an unchanged projection', () async {
    final plan = _planWithRefundAndTermination();
    final repository = _ControllableAmortizationRepository();
    final query = AmortizationBusinessActivityItemQueryService(
      AmortizationPlanQueryService(repository),
    );
    final events = <Map<String, AmortizationBusinessActivityItemProjection>>[];
    final subscription = query
        .watchForTransactions({
          plan.id: {'refund-tx'},
        })
        .listen(events.add);
    addTearDown(subscription.cancel);

    repository.add([plan]);
    await pumpEventQueue();
    repository.add([plan]);
    await pumpEventQueue();

    expect(events, hasLength(1));
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
  Set<String>? lastWatchIds;

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
  Stream<List<AmortizationPlan>> watchByIds(Set<String> ids) {
    lastWatchIds = Set.unmodifiable(ids);
    return Stream.value([
      for (final plan in plans)
        if (ids.contains(plan.id)) plan,
    ]);
  }

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<void> save(AmortizationPlan plan) async {}
}

final class _ControllableAmortizationRepository
    implements AmortizationRepository {
  final _controller = StreamController<List<AmortizationPlan>>.broadcast();

  void add(List<AmortizationPlan> plans) => _controller.add(plans);

  @override
  Stream<List<AmortizationPlan>> watchByIds(Set<String> ids) =>
      _controller.stream.map(
        (plans) => [
          for (final plan in plans)
            if (ids.contains(plan.id)) plan,
        ],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
