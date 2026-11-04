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
import 'package:smartflow/shared/business_activity/business_activity_item_key.dart';
import 'package:smartflow/shared/business_activity/business_activity_item_role.dart';

void main() {
  test('projects only requested amortization transactions', () async {
    final plan = _planWithRefundAndTermination();
    final repository = _FakeAmortizationRepository([plan]);
    final query = AmortizationBusinessActivityItemQueryService(
      AmortizationPlanQueryService(repository),
    );

    final items = await query.findItemsForTransactions({
      plan.id: {
        'refund-tx',
        'termination-recognition-tx',
        'termination-return-tx',
        'unrelated-tx',
      },
    });

    expect(
      items.keys,
      containsAll([
        'refund-tx',
        'termination-recognition-tx',
        'termination-return-tx',
      ]),
    );
    expect(items.keys, isNot(contains('unrelated-tx')));
    final refundItem = items['refund-tx']!;
    final refundProjection = refundItem.projectionFor('refund-tx')!;
    expect(refundProjection.factKind, AmortizationTransactionFactKind.refund);
    expect(refundItem.role, BusinessActivityItemRole.followUp);
    expect(
      refundItem.itemKey,
      const BusinessActivityItemKey(
        type: amortizationRefundBusinessActivityItemType,
        id: 'refund',
      ),
    );
    expect(refundItem.refundId, 'refund');
    expect(
      refundProjection.localCategoryAllocations.single.amount,
      const Money(minorUnits: 1000),
    );

    final terminationRecognition = items['termination-recognition-tx']!;
    final terminationReturn = items['termination-return-tx']!;
    expect(terminationReturn.itemKey, terminationRecognition.itemKey);
    expect(terminationRecognition.projections, hasLength(2));
    expect(terminationRecognition.projections.map((item) => item.factKind), [
      AmortizationTransactionFactKind.terminationRecognition,
      AmortizationTransactionFactKind.terminationReturn,
    ]);
    expect(
      terminationRecognition.itemKey,
      const BusinessActivityItemKey(
        type: amortizationTerminationBusinessActivityItemType,
        id: 'termination',
      ),
    );
    expect(terminationRecognition.role, BusinessActivityItemRole.followUp);
    expect(terminationRecognition.terminationId, 'termination');
  });

  test('watch requests only the current plan IDs', () async {
    final plan = _planWithRefundAndTermination();
    final repository = _FakeAmortizationRepository([plan]);
    final query = AmortizationBusinessActivityItemQueryService(
      AmortizationPlanQueryService(repository),
    );

    final items = await query.watchItemsForTransactions({
      plan.id: {'refund-tx'},
    }).first;

    expect(repository.lastWatchIds, {plan.id});
    expect(items['refund-tx']!.projections.single.refundId, 'refund');
  });

  test(
    'watching either termination projection returns one shared item',
    () async {
      final plan = _planWithRefundAndTermination();
      final repository = _FakeAmortizationRepository([plan]);
      final query = AmortizationBusinessActivityItemQueryService(
        AmortizationPlanQueryService(repository),
      );

      final items = await query.watchItemsForTransactions({
        plan.id: {'termination-recognition-tx', 'termination-return-tx'},
      }).first;

      expect(items, hasLength(2));
      expect(
        items['termination-recognition-tx'],
        same(items['termination-return-tx']),
      );
      expect(items.values.first.projections, hasLength(2));
    },
  );

  test('watch does not emit an unchanged projection', () async {
    final plan = _planWithRefundAndTermination();
    final repository = _ControllableAmortizationRepository();
    final query = AmortizationBusinessActivityItemQueryService(
      AmortizationPlanQueryService(repository),
    );
    final events = <Map<String, AmortizationBusinessActivityItemReadModel>>[];
    final subscription = query
        .watchItemsForTransactions({
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

  test('one projection change emits one logical item', () async {
    final original = _planWithRefundAndTermination();
    final changed = _planWithRefundAndTermination(terminationReturnMinor: 500);
    final repository = _ControllableAmortizationRepository();
    final query = AmortizationBusinessActivityItemQueryService(
      AmortizationPlanQueryService(repository),
    );
    final events = <Map<String, AmortizationBusinessActivityItemReadModel>>[];
    final subscription = query
        .watchItemsForTransactions({
          original.id: {'termination-recognition-tx', 'termination-return-tx'},
        })
        .listen(events.add);
    addTearDown(subscription.cancel);

    repository.add([original]);
    await pumpEventQueue();
    repository.add([changed]);
    await pumpEventQueue();

    expect(events, hasLength(2));
    expect(events.last.keys, hasLength(2));
    expect(
      events.last.values.map((item) => item.itemKey).toSet(),
      hasLength(1),
    );
    expect(
      events.last.values.first
          .projectionFor('termination-return-tx')!
          .localCategoryAllocations
          .single
          .amount,
      const Money(minorUnits: 500),
    );
  });
}

AmortizationPlan _planWithRefundAndTermination({
  int terminationReturnMinor = 1000,
}) {
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
      categoryReturnAllocations: singleAllocation(
        accountId: 'rent',
        amount: Money(minorUnits: terminationReturnMinor),
      ),
      settlementAllocations: singleAllocation(
        accountId: 'cash',
        amount: Money(minorUnits: terminationReturnMinor),
      ),
      recognitionTransactionId: 'termination-recognition-tx',
      returnTransactionId: 'termination-return-tx',
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
