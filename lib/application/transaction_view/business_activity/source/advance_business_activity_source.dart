import '../../../../domain/orchestration/entity/advance_case.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../ledger/transaction/query/transaction_query_service.dart';
import '../../../orchestration/advance/query/advance_case_query_service.dart';
import '../../../orchestration/advance/query/advance_transaction_view_query_service.dart';
import '../../../orchestration/advance/query/advance_transaction_view_read_models.dart';
import '../../transaction_view_query_streams.dart';
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
    final (cases, transactions) = await (
      _cases.findByIds({
        for (final candidate in values) candidate.activityKey.id,
      }),
      _transactions.findTransactionsByIds({
        for (final candidate in values) ?candidate.displayTransactionId,
      }),
    ).wait;
    final transactionsById = {
      for (final transaction in transactions) transaction.id: transaction,
    };
    return {
      for (final candidate in values)
        candidate.activityKey: _summaryFor(candidate, cases, transactionsById),
    };
  }

  @override
  Stream<Map<BusinessActivityKey, BusinessActivitySummary>> watchSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  ) {
    final values = candidates.toList();
    if (values.isEmpty) return Stream.value(const {});
    final ownerIds = {for (final candidate in values) candidate.activityKey.id};
    final transactionIds = {
      for (final candidate in values) ?candidate.displayTransactionId,
    };
    final signals = <Stream<Object?>>[
      for (final ownerId in ownerIds)
        _cases.watchById(ownerId).map<Object?>((value) => value),
      _transactions
          .watchTransactionsByIds(transactionIds)
          .map<Object?>((value) => value),
    ];
    return combineLatestStreams(signals).asyncMap((_) => findSummaries(values));
  }

  AdvanceBusinessActivitySummary _summaryFor(
    BusinessActivityCandidate candidate,
    Map<String, AdvanceCase> cases,
    Map<String, TransactionReadModel> transactionsById,
  ) {
    final advanceCase = cases[candidate.activityKey.id];
    if (advanceCase == null) {
      throw StateError(
        'Advance case ${candidate.activityKey.id} for business activity was '
        'not found.',
      );
    }
    final displayTransactionId = candidate.displayTransactionId;
    final facts = displayTransactionId == null
        ? null
        : transactionsById[displayTransactionId]?.advanceSummary;
    if (facts == null) {
      throw StateError(
        'Advance facts for display transaction $displayTransactionId were not '
        'found.',
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
          anchorAt: cursor.activityAt,
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
      candidates: [
        for (final anchor in page.anchors)
          BusinessActivityCandidate(
            activityKey: BusinessActivityKey(
              type: orchestrationAdvanceOwnerType,
              id: anchor.ownerId,
            ),
            activityAt: anchor.anchorAt,
            displayTransactionId: anchor.anchorTransactionId,
          ),
      ],
    );
  }
}
