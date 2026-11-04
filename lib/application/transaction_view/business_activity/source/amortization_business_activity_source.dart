import '../../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../orchestration/amortization/query/amortization_plan_query_service.dart';
import '../../../orchestration/amortization/query/amortization_transaction_view_query_service.dart';
import '../../../orchestration/amortization/query/amortization_transaction_view_read_models.dart';
import '../../transaction_view_query_port_api.dart';

/// Consumer-side adapter over amortization anchors and reusable plan queries.
final class AmortizationBusinessActivitySource
    implements BusinessActivitySource {
  const AmortizationBusinessActivitySource(this._anchors, this._plans);

  final AmortizationTransactionViewQueryService _anchors;
  final AmortizationPlanQueryService _plans;

  @override
  String get sourceKey => 'amortization';

  @override
  Set<String> get supportedActivityTypes => const {
    orchestrationAmortizationOwnerType,
  };

  @override
  Future<BusinessActivitySourcePage> findCandidatePage(
    BusinessActivityPageQuery query,
  ) async {
    return _mapPage(await _anchors.findAnchorPage(_queryFor(query)));
  }

  @override
  Stream<BusinessActivitySourcePage> watchCandidatePage(
    BusinessActivityPageQuery query,
  ) {
    return _anchors.watchAnchorPage(_queryFor(query)).map(_mapPage);
  }

  @override
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  ) async {
    final values = candidates.toList();
    final plans = await _plans.findByIds({
      for (final candidate in values) candidate.activityKey.id,
    });
    return _summariesFor(values, plans);
  }

  @override
  Stream<Map<BusinessActivityKey, BusinessActivitySummary>> watchSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  ) {
    final values = candidates.toList();
    if (values.isEmpty) return Stream.value(const {});
    final planIds = {for (final candidate in values) candidate.activityKey.id};
    return _plans
        .watchByIds(planIds)
        .asyncMap((plans) async => _summariesFor(values, plans));
  }

  Map<BusinessActivityKey, BusinessActivitySummary> _summariesFor(
    List<BusinessActivityCandidate> candidates,
    Iterable<AmortizationPlan> plans,
  ) {
    final plansById = {for (final plan in plans) plan.id: plan};
    return {
      for (final candidate in candidates)
        candidate.activityKey: _summaryFor(candidate, plansById),
    };
  }

  AmortizationBusinessActivitySummary _summaryFor(
    BusinessActivityCandidate candidate,
    Map<String, AmortizationPlan> plansById,
  ) {
    final plan = plansById[candidate.activityKey.id];
    if (plan == null) {
      throw StateError(
        'Amortization plan ${candidate.activityKey.id} for business activity '
        'was not found.',
      );
    }
    final current = plan.currentPendingPeriod;
    return AmortizationBusinessActivitySummary(
      kind: plan.kind,
      status: plan.status,
      originalAmount: plan.originalAmount,
      recognizedAmount: plan.recognizedAmount,
      remainingAmount: plan.remainingAmount,
      postedPeriodCount: plan.postedPeriodCount,
      totalPeriodCount: plan.periods.length,
      categoryAccountIds: [
        for (final allocation in plan.categoryAllocations) allocation.accountId,
      ],
      currentPeriodSequence: current?.sequenceNo,
      currentPeriodDueAt: current?.dueAt,
      currentPeriodAmount: current?.amount,
    );
  }

  AmortizationTransactionViewQuery _queryFor(BusinessActivityPageQuery query) {
    return AmortizationTransactionViewQuery(
      occurredFrom: query.occurredFrom,
      occurredUntil: query.occurredUntil,
      before: switch (query.before) {
        null => null,
        final cursor => AmortizationTransactionViewCursor(
          anchorAt: cursor.activityAt,
          activityType: cursor.activityKey.type,
          planId: cursor.activityKey.id,
        ),
      },
      limit: query.limit,
      categoryAccountIds: query.categoryAccountIds,
      settlementAccountIds: query.settlementAccountIds,
      tagIds: query.tagIds,
      untaggedOnly: query.untaggedOnly,
      counterpartyId: query.counterpartyId,
    );
  }

  BusinessActivitySourcePage _mapPage(
    AmortizationTransactionViewAnchorPage page,
  ) {
    return BusinessActivitySourcePage(
      hasMore: page.hasMore,
      candidates: [
        for (final anchor in page.anchors)
          BusinessActivityCandidate(
            activityKey: BusinessActivityKey(
              type: orchestrationAmortizationOwnerType,
              id: anchor.planId,
            ),
            activityAt: anchor.anchorAt,
            displayTransactionId: anchor.anchorTransactionId,
          ),
      ],
    );
  }
}
