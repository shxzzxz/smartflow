import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../orchestration/amortization/query/amortization_transaction_view_query_service.dart';
import '../../../orchestration/amortization/query/amortization_transaction_view_read_models.dart';
import '../../transaction_view_query_port_api.dart';

/// Consumer-side adapter over the amortization-owned transaction view query.
final class AmortizationBusinessItemSource implements BusinessItemSource {
  const AmortizationBusinessItemSource(this._query);

  final AmortizationTransactionViewQueryService _query;

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
    return _mapPage(await _query.findAnchorPage(_queryFor(query)));
  }

  @override
  Stream<BusinessItemSourcePage> watchAnchorPage(BusinessItemPageQuery query) {
    return _query.watchAnchorPage(_queryFor(query)).map(_mapPage);
  }

  @override
  Future<Map<BusinessItemKey, BusinessItemSummary>> findSummaries(
    Set<BusinessItemKey> itemKeys,
  ) async {
    final planIds = {
      for (final key in itemKeys)
        if (key.type == orchestrationAmortizationOwnerType) key.id,
    };
    final summaries = await _query.findSummaries(planIds);
    return {
      for (final entry in summaries.entries)
        BusinessItemKey(
          type: orchestrationAmortizationOwnerType,
          id: entry.key,
        ): AmortizationBusinessItemSummary(
          kind: entry.value.kind,
          status: entry.value.status,
          originalAmount: entry.value.originalAmount,
          recognizedAmount: entry.value.recognizedAmount,
          remainingAmount: entry.value.remainingAmount,
          postedPeriodCount: entry.value.postedPeriodCount,
          totalPeriodCount: entry.value.totalPeriodCount,
          currentPeriodSequence: entry.value.currentPeriodSequence,
          currentPeriodDueAt: entry.value.currentPeriodDueAt,
          currentPeriodAmount: entry.value.currentPeriodAmount,
        ),
    };
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
