import '../../../../domain/orchestration/entity/advance_case.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../ledger/transaction/query/transaction_query_service.dart';
import '../../../orchestration/advance/query/advance_case_query_service.dart';
import '../../../orchestration/advance/query/advance_transaction_view_query_service.dart';
import '../../../orchestration/advance/query/advance_transaction_view_read_models.dart';
import '../../transaction_view_query_port_api.dart';

/// Consumer-side adapter over advance metadata and ledger-owned facts.
final class AdvanceBusinessActivitySource implements BusinessActivitySource {
  const AdvanceBusinessActivitySource(
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
  Set<String> get supportedActivityTypes => const {
    orchestrationAdvanceOwnerType,
  };

  @override
  Future<BusinessActivitySourcePage> findAnchorPage(
    BusinessActivityPageQuery query,
  ) async {
    return _mapPage(await _anchors.findAnchorPage(_queryFor(query)));
  }

  @override
  Stream<BusinessActivitySourcePage> watchAnchorPage(
    BusinessActivityPageQuery query,
  ) {
    return _anchors.watchAnchorPage(_queryFor(query)).map(_mapPage);
  }

  @override
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityAnchorCandidate> anchors,
  ) async {
    final values = anchors.toList();
    final (cases, transactions) = await (
      _cases.findByIds({for (final anchor in values) anchor.activityKey.id}),
      _transactions.findTransactionsByIds({
        for (final anchor in values) anchor.anchorTransactionId,
      }),
    ).wait;
    final transactionsById = {
      for (final transaction in transactions) transaction.id: transaction,
    };
    return {
      for (final anchor in values)
        anchor.activityKey: _summaryFor(anchor, cases, transactionsById),
    };
  }

  AdvanceBusinessActivitySummary _summaryFor(
    BusinessActivityAnchorCandidate anchor,
    Map<String, AdvanceCase> cases,
    Map<String, TransactionReadModel> transactionsById,
  ) {
    final advanceCase = cases[anchor.activityKey.id];
    if (advanceCase == null) {
      throw StateError(
        'Advance case ${anchor.activityKey.id} for business activity was not found.',
      );
    }
    final facts = transactionsById[anchor.anchorTransactionId]?.advanceSummary;
    if (facts == null) {
      throw StateError(
        'Advance facts for anchor transaction ${anchor.anchorTransactionId} '
        'were not found.',
      );
    }
    return AdvanceBusinessActivitySummary(
      scenario: advanceCase.scenario,
      trackingMode: advanceCase.trackingMode,
      outstanding: facts.outstanding,
      isClosed: facts.isClosed,
      aaPeopleCount: advanceCase.aaPeopleCount,
    );
  }

  AdvanceTransactionViewQuery _queryFor(BusinessActivityPageQuery query) {
    return AdvanceTransactionViewQuery(
      occurredFrom: query.occurredFrom,
      occurredUntil: query.occurredUntil,
      before: switch (query.before) {
        null => null,
        final cursor => AdvanceTransactionViewCursor(
          anchorAt: cursor.anchorAt,
          activityType: cursor.activityKey.type,
          ownerId: cursor.activityKey.id,
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

  BusinessActivitySourcePage _mapPage(AdvanceTransactionViewAnchorPage page) {
    return BusinessActivitySourcePage(
      hasMore: page.hasMore,
      anchors: [
        for (final anchor in page.anchors)
          BusinessActivityAnchorCandidate(
            activityKey: BusinessActivityKey(
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
