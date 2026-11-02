import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../orchestration/advance/query/advance_transaction_view_query_service.dart';
import '../../../orchestration/advance/query/advance_transaction_view_read_models.dart';
import '../../transaction_view_query_port_api.dart';

/// Consumer-side adapter over the advance-owned transaction view query.
final class AdvanceBusinessItemSource implements BusinessItemSource {
  const AdvanceBusinessItemSource(this._query);

  final AdvanceTransactionViewQueryService _query;

  @override
  String get sourceKey => 'advance';

  @override
  Set<String> get supportedItemTypes => const {orchestrationAdvanceOwnerType};

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
    final ownerIds = {
      for (final key in itemKeys)
        if (key.type == orchestrationAdvanceOwnerType) key.id,
    };
    final summaries = await _query.findSummaries(ownerIds);
    return {
      for (final entry in summaries.entries)
        BusinessItemKey(
          type: orchestrationAdvanceOwnerType,
          id: entry.key,
        ): AdvanceBusinessItemSummary(
          scenario: entry.value.scenario,
          trackingMode: entry.value.trackingMode,
          outstanding: entry.value.outstanding,
          isClosed: entry.value.isClosed,
          aaPeopleCount: entry.value.aaPeopleCount,
        ),
    };
  }

  AdvanceTransactionViewQuery _queryFor(BusinessItemPageQuery query) {
    return AdvanceTransactionViewQuery(
      occurredFrom: query.occurredFrom,
      occurredUntil: query.occurredUntil,
      before: switch (query.before) {
        null => null,
        final cursor => AdvanceTransactionViewCursor(
          anchorAt: cursor.anchorAt,
          itemType: cursor.itemKey.type,
          ownerId: cursor.itemKey.id,
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

  BusinessItemSourcePage _mapPage(AdvanceTransactionViewAnchorPage page) {
    return BusinessItemSourcePage(
      hasMore: page.hasMore,
      anchors: [
        for (final anchor in page.anchors)
          BusinessItemAnchorCandidate(
            itemKey: BusinessItemKey(
              type: orchestrationAdvanceOwnerType,
              id: anchor.ownerId,
            ),
            anchorTransactionId: anchor.anchorTransactionId,
            anchorAt: anchor.anchorAt,
          ),
      ],
    );
  }
}
