import '../../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../orchestration/amortization/query/amortization_plan_query_service.dart';
import '../../../orchestration/amortization/query/amortization_transaction_view_query_service.dart';
import '../../../orchestration/amortization/query/amortization_transaction_view_read_models.dart';
import '../../transaction_view_query_port_api.dart';

/// Consumer-side adapter over amortization anchors and reusable plan queries.
final class AmortizationBusinessItemSource implements BusinessItemSource {
  const AmortizationBusinessItemSource(this._anchors, this._plans);

  final AmortizationTransactionViewQueryService _anchors;
  final AmortizationPlanQueryService _plans;

  @override
  String get sourceKey => 'amortization';

  @override
  Set<String> get supportedItemTypes => const {
    orchestrationAmortizationOwnerType,
  };

  @override
  Future<BusinessItemSourcePage> findAnchorPage(
    BusinessItemPageQuery query,
  ) async {
    return _mapPage(await _anchors.findAnchorPage(_queryFor(query)));
  }

  @override
  Stream<BusinessItemSourcePage> watchAnchorPage(BusinessItemPageQuery query) {
    return _anchors.watchAnchorPage(_queryFor(query)).map(_mapPage);
  }

  @override
  Future<Map<BusinessItemKey, BusinessItemSummary>> findSummaries(
    Iterable<BusinessItemAnchorCandidate> anchors,
  ) async {
    final plans = await _plans.findByIds({
      for (final anchor in anchors) anchor.itemKey.id,
    });
    final plansById = {for (final plan in plans) plan.id: plan};
    return {
      for (final anchor in anchors)
        anchor.itemKey: _summaryFor(anchor, plansById),
    };
  }

  AmortizationBusinessItemSummary _summaryFor(
    BusinessItemAnchorCandidate anchor,
    Map<String, AmortizationPlan> plansById,
  ) {
    final plan = plansById[anchor.itemKey.id];
    if (plan == null) {
      throw StateError(
        'Amortization plan ${anchor.itemKey.id} for business item was not '
        'found.',
      );
    }
    final current = plan.currentPendingPeriod;
    return AmortizationBusinessItemSummary(
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

  AmortizationTransactionViewQuery _queryFor(BusinessItemPageQuery query) {
    return AmortizationTransactionViewQuery(
      occurredFrom: query.occurredFrom,
      occurredUntil: query.occurredUntil,
      before: switch (query.before) {
        null => null,
        final cursor => AmortizationTransactionViewCursor(
          anchorAt: cursor.anchorAt,
          itemType: cursor.itemKey.type,
          planId: cursor.itemKey.id,
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

  BusinessItemSourcePage _mapPage(AmortizationTransactionViewAnchorPage page) {
    return BusinessItemSourcePage(
      hasMore: page.hasMore,
      anchors: [
        for (final anchor in page.anchors)
          BusinessItemAnchorCandidate(
            itemKey: BusinessItemKey(
              type: orchestrationAmortizationOwnerType,
              id: anchor.planId,
            ),
            anchorTransactionId: anchor.anchorTransactionId,
            anchorAt: anchor.anchorAt,
          ),
      ],
    );
  }
}
