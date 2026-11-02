import '../../../credit/credit_query_api.dart';
import '../../transaction_view_query_port_api.dart';

/// Consumer-side adapter over the credit-owned transaction view query.
final class CreditBusinessItemSource implements BusinessItemSource {
  const CreditBusinessItemSource(this._query);

  final CreditTransactionViewQueryService _query;

  @override
  String get sourceKey => 'credit';

  @override
  Set<String> get supportedItemTypes => const {
    installmentOwnerType,
    creditRepaymentOwnerType,
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
    final contractIds = {
      for (final key in itemKeys)
        if (key.type == installmentOwnerType) key.id,
    };
    final repaymentIds = {
      for (final key in itemKeys)
        if (key.type == creditRepaymentOwnerType) key.id,
    };
    final installmentSummaries = await _query.findInstallmentSummaries(
      contractIds,
    );
    final repaymentSummaries = await _query.findRepaymentSummaries(
      repaymentIds,
    );
    return {
      for (final entry in installmentSummaries.entries)
        BusinessItemKey(
          type: installmentOwnerType,
          id: entry.key,
        ): InstallmentBusinessItemSummary(
          installmentType: entry.value.installmentType,
          status: entry.value.status,
          principal: entry.value.principal,
          remainingPrincipal: entry.value.remainingPrincipal,
          paidPeriodCount: entry.value.paidPeriodCount,
          totalPeriodCount: entry.value.totalPeriodCount,
        ),
      for (final entry in repaymentSummaries.entries)
        BusinessItemKey(
          type: creditRepaymentOwnerType,
          id: entry.key,
        ): RepaymentBusinessItemSummary(
          repaymentType: entry.value.repaymentType,
          targetType: entry.value.targetType,
        ),
    };
  }

  CreditTransactionViewQuery _queryFor(BusinessItemPageQuery query) {
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

  BusinessItemSourcePage _mapPage(CreditTransactionViewAnchorPage page) {
    return BusinessItemSourcePage(
      hasMore: page.hasMore,
      anchors: [
        for (final anchor in page.anchors)
          BusinessItemAnchorCandidate(
            itemKey: BusinessItemKey(
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
