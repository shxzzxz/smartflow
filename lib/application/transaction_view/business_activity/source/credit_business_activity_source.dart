import '../../../credit/credit_query_api.dart';
import '../../transaction_view_query_port_api.dart';
import '../../transaction_view_query_streams.dart';

/// Consumer-side adapter over credit-owned anchor and installment queries.
final class CreditBusinessActivitySource implements BusinessActivitySource {
  const CreditBusinessActivitySource(this._query, this._installments);

  final CreditTransactionViewQueryService _query;
  final InstallmentQueryService _installments;

  @override
  String get sourceKey => 'credit';

  @override
  Set<String> get supportedActivityTypes => const {
    installmentOwnerType,
    creditRepaymentOwnerType,
  };

  @override
  Future<BusinessActivitySourcePage> findCandidatePage(
    BusinessActivityPageQuery query,
  ) async {
    return _mapPage(await _query.findAnchorPage(_queryFor(query)));
  }

  @override
  Stream<BusinessActivitySourcePage> watchCandidatePage(
    BusinessActivityPageQuery query,
  ) {
    return _query.watchAnchorPage(_queryFor(query)).map(_mapPage);
  }

  @override
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  ) async {
    final contractIds = {
      for (final candidate in candidates)
        if (candidate.activityKey.type == installmentOwnerType)
          candidate.activityKey.id,
    };
    final repaymentIds = {
      for (final candidate in candidates)
        if (candidate.activityKey.type == creditRepaymentOwnerType)
          candidate.activityKey.id,
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

  @override
  Stream<Map<BusinessActivityKey, BusinessActivitySummary>> watchSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  ) {
    final values = candidates.toList();
    if (values.isEmpty) return Stream.value(const {});
    final contractIds = {
      for (final candidate in values)
        if (candidate.activityKey.type == installmentOwnerType)
          candidate.activityKey.id,
    };
    final repaymentIds = {
      for (final candidate in values)
        if (candidate.activityKey.type == creditRepaymentOwnerType)
          candidate.activityKey.id,
    };
    final signals = <Stream<Object?>>[
      for (final contractId in contractIds)
        _installments
            .watchInstallment(contractId)
            .map<Object?>((value) => value),
      for (final repaymentId in repaymentIds)
        _query
            .watchRepaymentSummary(repaymentId)
            .map<Object?>((value) => value),
    ];
    return combineLatestStreams(signals).asyncMap((_) => findSummaries(values));
  }

  CreditTransactionViewQuery _queryFor(BusinessActivityPageQuery query) {
    final activityTypes = query.activityTypes;
    return CreditTransactionViewQuery(
      occurredFrom: query.occurredFrom,
      occurredUntil: query.occurredUntil,
      before: switch (query.before) {
        null => null,
        final cursor => CreditTransactionViewCursor(
          anchorAt: cursor.activityAt,
          activityType: cursor.activityKey.type,
          activityId: cursor.activityKey.id,
        ),
      },
      limit: query.limit,
      activityTypes: activityTypes == null
          ? null
          : {for (final value in activityTypes) ?_tryActivityType(value)},
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
      candidates: [
        for (final anchor in page.anchors)
          BusinessActivityCandidate(
            activityKey: BusinessActivityKey(
              type: anchor.activityType.code,
              id: anchor.activityId,
            ),
            activityAt: anchor.anchorAt,
            displayTransactionId: anchor.anchorTransactionId,
          ),
      ],
    );
  }

  CreditTransactionViewActivityType? _tryActivityType(String activityType) {
    return switch (activityType) {
      installmentOwnerType => CreditTransactionViewActivityType.installment,
      creditRepaymentOwnerType => CreditTransactionViewActivityType.repayment,
      _ => null,
    };
  }
}
