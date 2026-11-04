import '../../../../domain/ledger/valobj/account_amount_allocation.dart';
import '../../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../../shared/business_activity/business_activity_item_key.dart';
import '../../../../shared/business_activity/business_activity_item_role.dart';
import 'amortization_plan_query_service.dart';

const String amortizationPlanBusinessActivityItemType =
    'orchestration.amortization_plan';
const String amortizationPeriodBusinessActivityItemType =
    'orchestration.amortization_period';
const String amortizationRefundBusinessActivityItemType =
    'orchestration.amortization_refund';
const String amortizationTerminationBusinessActivityItemType =
    'orchestration.amortization_termination';

/// One logical amortization activity item and every transaction projection
/// that carries its local business facts.
final class AmortizationBusinessActivityItemReadModel {
  AmortizationBusinessActivityItemReadModel({
    required this.planId,
    required this.itemKey,
    required this.kind,
    required this.role,
    required Iterable<AmortizationBusinessActivityItemProjection> projections,
    this.refundId,
    this.terminationId,
  }) : projections = List.unmodifiable(projections) {
    if (this.projections.isEmpty) {
      throw ArgumentError.value(
        this.projections,
        'projections',
        'An amortization activity item requires at least one projection.',
      );
    }
    final transactionIds = <String>{};
    for (final projection in this.projections) {
      if (projection.planId != planId ||
          projection.itemKey != itemKey ||
          projection.kind != kind ||
          projection.role != role ||
          !transactionIds.add(projection.transactionId)) {
        throw ArgumentError.value(
          projection,
          'projections',
          'Projections must share one plan, item, kind and role, with unique '
              'transactions.',
        );
      }
    }
  }

  final String planId;
  final BusinessActivityItemKey itemKey;
  final AmortizationKind kind;
  final BusinessActivityItemRole role;
  final List<AmortizationBusinessActivityItemProjection> projections;
  final String? refundId;
  final String? terminationId;

  AmortizationBusinessActivityItemProjection? projectionFor(
    String transactionId,
  ) {
    for (final projection in projections) {
      if (projection.transactionId == transactionId) return projection;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is AmortizationBusinessActivityItemReadModel &&
        other.planId == planId &&
        other.itemKey == itemKey &&
        other.kind == kind &&
        other.role == role &&
        other.refundId == refundId &&
        other.terminationId == terminationId &&
        _sameProjections(other.projections, projections);
  }

  @override
  int get hashCode => Object.hash(
    planId,
    itemKey,
    kind,
    role,
    refundId,
    terminationId,
    Object.hashAll(projections),
  );
}

/// Business item facts for one amortization transaction.
///
/// Activity-level amounts and progress stay in the business activity summary.
final class AmortizationBusinessActivityItemProjection {
  AmortizationBusinessActivityItemProjection({
    required this.planId,
    required this.transactionId,
    required this.itemKey,
    required this.kind,
    required this.factKind,
    required this.role,
    required Iterable<AccountAmountAllocation> localCategoryAllocations,
    this.occurrencePeriodSequence,
    this.occurrencePeriodDueAt,
    this.refundId,
    this.terminationId,
  }) : localCategoryAllocations = List.unmodifiable(localCategoryAllocations);

  final String planId;
  final String transactionId;
  final BusinessActivityItemKey itemKey;
  final AmortizationKind kind;
  final AmortizationTransactionFactKind factKind;
  final BusinessActivityItemRole role;
  final List<AccountAmountAllocation> localCategoryAllocations;
  final int? occurrencePeriodSequence;
  final DateTime? occurrencePeriodDueAt;
  final String? refundId;
  final String? terminationId;

  @override
  bool operator ==(Object other) {
    return other is AmortizationBusinessActivityItemProjection &&
        other.planId == planId &&
        other.transactionId == transactionId &&
        other.itemKey == itemKey &&
        other.kind == kind &&
        other.factKind == factKind &&
        other.role == role &&
        _sameAllocations(
          other.localCategoryAllocations,
          localCategoryAllocations,
        ) &&
        other.occurrencePeriodSequence == occurrencePeriodSequence &&
        other.occurrencePeriodDueAt == occurrencePeriodDueAt &&
        other.refundId == refundId &&
        other.terminationId == terminationId;
  }

  @override
  int get hashCode => Object.hash(
    planId,
    transactionId,
    itemKey,
    kind,
    factKind,
    role,
    Object.hashAll([
      for (final allocation in localCategoryAllocations)
        (allocation.accountId, allocation.amount.minorUnits),
    ]),
    occurrencePeriodSequence,
    occurrencePeriodDueAt,
    refundId,
    terminationId,
  );
}

/// Projects the logical activity items hit by the requested transactions.
/// Each returned item carries all of its own projections while unrelated plan
/// facts stay out of the result. Owner-level summaries remain separate.
class AmortizationBusinessActivityItemQueryService {
  const AmortizationBusinessActivityItemQueryService(this._plans);

  final AmortizationPlanQueryService _plans;

  Future<Map<String, AmortizationBusinessActivityItemReadModel>>
  findItemsForTransactions(
    Map<String, Set<String>> transactionIdsByPlanId,
  ) async {
    if (transactionIdsByPlanId.isEmpty) return const {};
    final plans = await _plans.findByIds(transactionIdsByPlanId.keys.toSet());
    return _projectItems(plans, transactionIdsByPlanId);
  }

  Stream<Map<String, AmortizationBusinessActivityItemReadModel>>
  watchItemsForTransactions(Map<String, Set<String>> transactionIdsByPlanId) {
    if (transactionIdsByPlanId.isEmpty) {
      return Stream.value(const {});
    }
    final planIds = transactionIdsByPlanId.keys.toSet();
    return _plans
        .watchByIds(planIds)
        .map((plans) => _projectItems(plans, transactionIdsByPlanId))
        .distinct(_sameItems);
  }

  Future<Map<String, AmortizationBusinessActivityItemProjection>>
  findForTransactions(Map<String, Set<String>> transactionIdsByPlanId) async {
    final items = await findItemsForTransactions(transactionIdsByPlanId);
    return {
      for (final entry in items.entries)
        entry.key: ?entry.value.projectionFor(entry.key),
    };
  }

  Stream<Map<String, AmortizationBusinessActivityItemProjection>>
  watchForTransactions(Map<String, Set<String>> transactionIdsByPlanId) {
    return watchItemsForTransactions(transactionIdsByPlanId).map((items) {
      return {
        for (final entry in items.entries)
          entry.key: ?entry.value.projectionFor(entry.key),
      };
    });
  }

  Map<String, AmortizationBusinessActivityItemReadModel> _projectItems(
    Iterable<AmortizationPlan> plans,
    Map<String, Set<String>> transactionIdsByPlanId,
  ) {
    final items = <String, AmortizationBusinessActivityItemReadModel>{};
    for (final plan in plans) {
      final transactionIds = transactionIdsByPlanId[plan.id] ?? const {};
      if (transactionIds.isEmpty) continue;
      final requestedFactKinds = {
        for (final transactionId in transactionIds)
          transactionId: ?plan.transactionFactKind(transactionId),
      };
      if (requestedFactKinds.isEmpty) continue;
      final requestedItemKeys = {
        for (final entry in requestedFactKinds.entries)
          _itemKeyFor(plan, entry.key, entry.value),
      };

      final projectionsByItem =
          <
            BusinessActivityItemKey,
            List<AmortizationBusinessActivityItemProjection>
          >{};
      for (final projection in _projectPlan(
        plan,
        requestedItemKeys: requestedItemKeys,
      )) {
        projectionsByItem
            .putIfAbsent(projection.itemKey, () => [])
            .add(projection);
      }
      final itemsByKey = {
        for (final entry in projectionsByItem.entries)
          entry.key: AmortizationBusinessActivityItemReadModel(
            planId: plan.id,
            itemKey: entry.key,
            kind: plan.kind,
            role: entry.value.first.role,
            refundId: entry.value.first.refundId,
            terminationId: entry.value.first.terminationId,
            projections: entry.value,
          ),
      };
      for (final entry in requestedFactKinds.entries) {
        final itemKey = _itemKeyFor(plan, entry.key, entry.value);
        if (itemsByKey[itemKey] case final item?) {
          items[entry.key] = item;
        }
      }
    }
    return items;
  }

  Iterable<AmortizationBusinessActivityItemProjection> _projectPlan(
    AmortizationPlan plan, {
    required Set<BusinessActivityItemKey> requestedItemKeys,
  }) sync* {
    final initialItemKey = BusinessActivityItemKey(
      type: amortizationPlanBusinessActivityItemType,
      id: plan.id,
    );
    if (requestedItemKeys.contains(initialItemKey)) {
      yield AmortizationBusinessActivityItemProjection(
        planId: plan.id,
        transactionId: plan.initialTransactionId,
        itemKey: initialItemKey,
        kind: plan.kind,
        factKind: AmortizationTransactionFactKind.initial,
        role: BusinessActivityItemRole.origin,
        localCategoryAllocations: plan.categoryAllocations,
      );
    }
    for (final period in plan.periods) {
      final transactionId = period.transactionId;
      if (transactionId == null) continue;
      final itemKey = BusinessActivityItemKey(
        type: amortizationPeriodBusinessActivityItemType,
        id: period.id,
      );
      if (!requestedItemKeys.contains(itemKey)) continue;
      yield AmortizationBusinessActivityItemProjection(
        planId: plan.id,
        transactionId: transactionId,
        itemKey: itemKey,
        kind: plan.kind,
        factKind: AmortizationTransactionFactKind.recognition,
        role: BusinessActivityItemRole.followUp,
        localCategoryAllocations: period.categoryAllocations,
        occurrencePeriodSequence: period.sequenceNo,
        occurrencePeriodDueAt: period.dueAt,
      );
    }
    for (final refund in plan.refunds) {
      final itemKey = BusinessActivityItemKey(
        type: amortizationRefundBusinessActivityItemType,
        id: refund.id,
      );
      if (!requestedItemKeys.contains(itemKey)) continue;
      yield AmortizationBusinessActivityItemProjection(
        planId: plan.id,
        transactionId: refund.transferTransactionId,
        itemKey: itemKey,
        kind: plan.kind,
        factKind: AmortizationTransactionFactKind.refund,
        role: BusinessActivityItemRole.followUp,
        localCategoryAllocations: refund.categoryAllocations,
        refundId: refund.id,
      );
    }
    final termination = plan.termination;
    if (termination == null) return;
    final terminationItemKey = BusinessActivityItemKey(
      type: amortizationTerminationBusinessActivityItemType,
      id: termination.id,
    );
    if (!requestedItemKeys.contains(terminationItemKey)) return;
    final recognitionTransactionId = termination.recognitionTransactionId;
    if (recognitionTransactionId != null) {
      yield AmortizationBusinessActivityItemProjection(
        planId: plan.id,
        transactionId: recognitionTransactionId,
        itemKey: terminationItemKey,
        kind: plan.kind,
        factKind: AmortizationTransactionFactKind.terminationRecognition,
        role: BusinessActivityItemRole.followUp,
        localCategoryAllocations:
            plan.terminationRecognitionCategoryAllocations,
        terminationId: termination.id,
      );
    }
    final returnTransactionId = termination.returnTransactionId;
    if (returnTransactionId != null) {
      yield AmortizationBusinessActivityItemProjection(
        planId: plan.id,
        transactionId: returnTransactionId,
        itemKey: terminationItemKey,
        kind: plan.kind,
        factKind: AmortizationTransactionFactKind.terminationReturn,
        role: BusinessActivityItemRole.followUp,
        localCategoryAllocations: termination.categoryReturnAllocations,
        terminationId: termination.id,
      );
    }
  }

  BusinessActivityItemKey _itemKeyFor(
    AmortizationPlan plan,
    String transactionId,
    AmortizationTransactionFactKind factKind,
  ) {
    return switch (factKind) {
      AmortizationTransactionFactKind.initial => BusinessActivityItemKey(
        type: amortizationPlanBusinessActivityItemType,
        id: plan.id,
      ),
      AmortizationTransactionFactKind.recognition => BusinessActivityItemKey(
        type: amortizationPeriodBusinessActivityItemType,
        id: plan.periods
            .singleWhere((period) => period.transactionId == transactionId)
            .id,
      ),
      AmortizationTransactionFactKind.refund => BusinessActivityItemKey(
        type: amortizationRefundBusinessActivityItemType,
        id: plan.refunds
            .singleWhere(
              (refund) => refund.transferTransactionId == transactionId,
            )
            .id,
      ),
      AmortizationTransactionFactKind.terminationRecognition ||
      AmortizationTransactionFactKind.terminationReturn =>
        BusinessActivityItemKey(
          type: amortizationTerminationBusinessActivityItemType,
          id: plan.termination!.id,
        ),
    };
  }

  bool _sameItems(
    Map<String, AmortizationBusinessActivityItemReadModel> left,
    Map<String, AmortizationBusinessActivityItemReadModel> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }
}

bool _sameProjections(
  List<AmortizationBusinessActivityItemProjection> left,
  List<AmortizationBusinessActivityItemProjection> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameAllocations(
  List<AccountAmountAllocation> left,
  List<AccountAmountAllocation> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    final leftValue = left[index];
    final rightValue = right[index];
    if (leftValue.accountId != rightValue.accountId ||
        leftValue.amount != rightValue.amount) {
      return false;
    }
  }
  return true;
}
