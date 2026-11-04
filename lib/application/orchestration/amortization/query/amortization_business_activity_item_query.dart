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

/// Projects only the amortization transactions requested by a transaction
/// view. Transaction roles and owner-level summaries stay in the amortization
/// application domain.
class AmortizationBusinessActivityItemQueryService {
  const AmortizationBusinessActivityItemQueryService(this._plans);

  final AmortizationPlanQueryService _plans;

  Future<Map<String, AmortizationBusinessActivityItemProjection>>
  findForTransactions(Map<String, Set<String>> transactionIdsByPlanId) async {
    if (transactionIdsByPlanId.isEmpty) return const {};
    final plans = await _plans.findByIds(transactionIdsByPlanId.keys.toSet());
    return _project(plans, transactionIdsByPlanId);
  }

  Stream<Map<String, AmortizationBusinessActivityItemProjection>>
  watchForTransactions(Map<String, Set<String>> transactionIdsByPlanId) {
    if (transactionIdsByPlanId.isEmpty) {
      return Stream.value(const {});
    }
    final planIds = transactionIdsByPlanId.keys.toSet();
    return _plans
        .watchByIds(planIds)
        .map((plans) => _project(plans, transactionIdsByPlanId))
        .distinct(_sameProjections);
  }

  Map<String, AmortizationBusinessActivityItemProjection> _project(
    Iterable<AmortizationPlan> plans,
    Map<String, Set<String>> transactionIdsByPlanId,
  ) {
    final items = <String, AmortizationBusinessActivityItemProjection>{};
    for (final plan in plans) {
      final transactionIds = transactionIdsByPlanId[plan.id] ?? const {};
      for (final transactionId in transactionIds) {
        final factKind = plan.transactionFactKind(transactionId);
        if (factKind == null) continue;
        final period = plan.periods
            .where((period) => period.transactionId == transactionId)
            .firstOrNull;
        final refund = plan.refunds
            .where((refund) => refund.transferTransactionId == transactionId)
            .firstOrNull;
        final termination = plan.termination;
        final localCategories = switch (factKind) {
          AmortizationTransactionFactKind.initial => plan.categoryAllocations,
          AmortizationTransactionFactKind.recognition =>
            period?.categoryAllocations ?? const [],
          AmortizationTransactionFactKind.refund =>
            refund?.categoryAllocations ?? const [],
          AmortizationTransactionFactKind.terminationRecognition =>
            plan.terminationRecognitionCategoryAllocations,
          AmortizationTransactionFactKind.terminationReturn =>
            termination?.categoryReturnAllocations ?? const [],
        };
        final itemKey = switch (factKind) {
          AmortizationTransactionFactKind.initial => BusinessActivityItemKey(
            type: amortizationPlanBusinessActivityItemType,
            id: plan.id,
          ),
          AmortizationTransactionFactKind.recognition =>
            BusinessActivityItemKey(
              type: amortizationPeriodBusinessActivityItemType,
              id: period!.id,
            ),
          AmortizationTransactionFactKind.refund => BusinessActivityItemKey(
            type: amortizationRefundBusinessActivityItemType,
            id: refund!.id,
          ),
          AmortizationTransactionFactKind.terminationRecognition ||
          AmortizationTransactionFactKind.terminationReturn =>
            BusinessActivityItemKey(
              type: amortizationTerminationBusinessActivityItemType,
              id: termination!.id,
            ),
        };
        items[transactionId] = AmortizationBusinessActivityItemProjection(
          planId: plan.id,
          transactionId: transactionId,
          itemKey: itemKey,
          kind: plan.kind,
          localCategoryAllocations: localCategories,
          occurrencePeriodSequence: period?.sequenceNo,
          occurrencePeriodDueAt: period?.dueAt,
          factKind: factKind,
          role: factKind == AmortizationTransactionFactKind.initial
              ? BusinessActivityItemRole.origin
              : BusinessActivityItemRole.followUp,
          refundId: refund?.id,
          terminationId:
              factKind ==
                      AmortizationTransactionFactKind.terminationRecognition ||
                  factKind == AmortizationTransactionFactKind.terminationReturn
              ? termination?.id
              : null,
        );
      }
    }
    return items;
  }

  bool _sameProjections(
    Map<String, AmortizationBusinessActivityItemProjection> left,
    Map<String, AmortizationBusinessActivityItemProjection> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }
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
