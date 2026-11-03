import '../../../credit/credit_query_api.dart';
import '../../transaction_view_query_port_api.dart';

/// Consumer-side adapter over credit-owned anchor and installment queries.
final class CreditBusinessActivitySource implements BusinessActivitySource {
  const CreditBusinessActivitySource(this._query, this._installments);

  final CreditTransactionViewQueryService _query;
  final InstallmentQueryService _installments;

  @override
  String get sourceKey => 'credit';

  @override
  Set<String> get supportedItemTypes => const {
    installmentOwnerType,
    creditRepaymentOwnerType,
  };

  @override
  Future<BusinessActivitySourcePage> findAnchorPage(
    BusinessActivityPageQuery query,
  ) async {
    return _mapPage(await _query.findAnchorPage(_queryFor(query)));
  }

  @override
  Stream<BusinessActivitySourcePage> watchAnchorPage(
    BusinessActivityPageQuery query,
  ) {
    return _query.watchAnchorPage(_queryFor(query)).map(_mapPage);
  }

  @override
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityAnchorCandidate> anchors,
  ) async {
    final contractIds = {
      for (final anchor in anchors)
        if (anchor.itemKey.type == installmentOwnerType) anchor.itemKey.id,
    };
    final repaymentIds = {
      for (final anchor in anchors)
        if (anchor.itemKey.type == creditRepaymentOwnerType) anchor.itemKey.id,
    };
    final installmentSummaries = await _installments.findInstallments(
      contractIds,
    );
    final repaymentSummaries = await _query.findRepaymentSummaries(
      repaymentIds,
    );
    return {
      for (final entry in installmentSummaries.entries)
        BusinessActivityKey(
          type: installmentOwnerType,
          id: entry.key,
        ): InstallmentBusinessActivitySummary(
          installmentType: entry.value.installmentType,
          status: entry.value.status,
          principal: entry.value.principal,
          remainingPrincipal: entry.value.repaymentProgress.remainingPrincipal,
          paidPeriodCount: entry.value.repaymentProgress.paidPeriodCount,
          totalPeriodCount: entry.value.repaymentProgress.totalPeriodCount,
        ),
      for (final entry in repaymentSummaries.entries)
        BusinessActivityKey(
          type: creditRepaymentOwnerType,
          id: entry.key,
        ): RepaymentBusinessActivitySummary(
          repaymentType: entry.value.repaymentType,
          targetType: entry.value.targetType,
        ),
    };
  }

  CreditTransactionViewQuery _queryFor(BusinessActivityPageQuery query) {
    final itemTypes = query.itemTypes;
    return CreditTransactionViewQuery(
      occurredFrom: query.occurredFrom,
      occurredUntil: query.occurredUntil,
      before: switch (query.before) {
        null => null,
        final cursor => CreditTransactionViewCursor(
          anchorAt: cursor.anchorAt,
          itemType: cursor.itemKey.type,
          itemId: cursor.itemKey.id,
        ),
      },
      limit: query.limit,
      itemTypes: itemTypes == null
          ? null
          : {for (final value in itemTypes) ?_tryItemType(value)},
      categoryAccountIds: query.categoryAccountIds,
      settlementAccountIds: query.settlementAccountIds,
      tagIds: query.tagIds,
      untaggedOnly: query.untaggedOnly,
      counterpartyId: query.counterpartyId,
    );
  }

  BusinessActivitySourcePage _mapPage(CreditTransactionViewAnchorPage page) {
    return BusinessActivitySourcePage(
      hasMore: page.hasMore,
      anchors: [
        for (final anchor in page.anchors)
          BusinessActivityAnchorCandidate(
            itemKey: BusinessActivityKey(
              type: anchor.itemType.code,
              id: anchor.itemId,
            ),
            anchorTransactionId: anchor.anchorTransactionId,
            anchorAt: anchor.anchorAt,
          ),
      ],
    );
  }

  CreditTransactionViewItemType? _tryItemType(String itemType) {
    return switch (itemType) {
      installmentOwnerType => CreditTransactionViewItemType.installment,
      creditRepaymentOwnerType => CreditTransactionViewItemType.repayment,
      _ => null,
    };
  }
}
