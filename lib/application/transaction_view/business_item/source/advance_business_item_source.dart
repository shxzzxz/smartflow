import '../../../../domain/orchestration/entity/advance_case.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../ledger/transaction/query/transaction_query_service.dart';
import '../../../orchestration/advance/query/advance_case_query_service.dart';
import '../../../orchestration/advance/query/advance_transaction_view_query_service.dart';
import '../../../orchestration/advance/query/advance_transaction_view_read_models.dart';
import '../../transaction_view_query_port_api.dart';

/// Consumer-side adapter over advance metadata and ledger-owned facts.
final class AdvanceBusinessItemSource implements BusinessItemSource {
  const AdvanceBusinessItemSource(
    this._anchors,
    this._cases,
    this._transactions,
  );

  final AdvanceTransactionViewQueryService _anchors;
  final AdvanceCaseQueryService _cases;
  final TransactionBatchQueryService _transactions;

  @override
  String get sourceKey => 'advance';

  @override
  Set<String> get supportedItemTypes => const {orchestrationAdvanceOwnerType};

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
    final values = anchors.toList();
    final (cases, transactions) = await (
      _cases.findByIds({for (final anchor in values) anchor.itemKey.id}),
      _transactions.findTransactionsByIds({
        for (final anchor in values) anchor.anchorTransactionId,
      }),
    ).wait;
    final transactionsById = {
      for (final transaction in transactions) transaction.id: transaction,
    };
    return {
      for (final anchor in values)
        anchor.itemKey: _summaryFor(anchor, cases, transactionsById),
    };
  }

  AdvanceBusinessItemSummary _summaryFor(
    BusinessItemAnchorCandidate anchor,
    Map<String, AdvanceCase> cases,
    Map<String, TransactionReadModel> transactionsById,
  ) {
    final advanceCase = cases[anchor.itemKey.id];
    if (advanceCase == null) {
      throw StateError(
        'Advance case ${anchor.itemKey.id} for business item was not found.',
      );
    }
    final facts = transactionsById[anchor.anchorTransactionId]?.advanceSummary;
    if (facts == null) {
      throw StateError(
        'Advance facts for anchor transaction ${anchor.anchorTransactionId} '
        'were not found.',
      );
    }
    return AdvanceBusinessItemSummary(
      scenario: advanceCase.scenario,
      trackingMode: advanceCase.trackingMode,
      outstanding: facts.outstanding,
      isClosed: facts.isClosed,
      aaPeopleCount: advanceCase.aaPeopleCount,
    );
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
