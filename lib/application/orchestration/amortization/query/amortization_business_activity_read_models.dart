final class AmortizationBusinessActivityQuery {
  AmortizationBusinessActivityQuery({
    required this.occurredFrom,
    required this.occurredUntil,
    this.before,
    this.limit = 20,
    Set<String>? categoryAccountIds,
    Set<String>? settlementAccountIds,
    Set<String>? tagIds,
    this.untaggedOnly = false,
    this.counterpartyId,
  }) : categoryAccountIds = _immutableStrings(categoryAccountIds),
       settlementAccountIds = _immutableStrings(settlementAccountIds),
       tagIds = _immutableStrings(tagIds),
       assert(occurredUntil.isAfter(occurredFrom)),
       assert(limit > 0),
       assert(!untaggedOnly || tagIds == null);

  final DateTime occurredFrom;
  final DateTime occurredUntil;
  final AmortizationBusinessActivityCursor? before;
  final int limit;
  final Set<String>? categoryAccountIds;
  final Set<String>? settlementAccountIds;
  final Set<String>? tagIds;
  final bool untaggedOnly;
  final String? counterpartyId;
}

final class AmortizationBusinessActivityCursor {
  const AmortizationBusinessActivityCursor({
    required this.anchorAt,
    required this.activityType,
    required this.planId,
  });

  final DateTime anchorAt;
  final String activityType;
  final String planId;
}

final class AmortizationBusinessActivityAnchorCandidate {
  const AmortizationBusinessActivityAnchorCandidate({
    required this.planId,
    required this.anchorTransactionId,
    required this.anchorAt,
  });

  final String planId;
  final String anchorTransactionId;
  final DateTime anchorAt;
}

final class AmortizationBusinessActivityAnchorPage {
  AmortizationBusinessActivityAnchorPage({
    required Iterable<AmortizationBusinessActivityAnchorCandidate> anchors,
    required this.hasMore,
  }) : anchors = List.unmodifiable(anchors);

  final List<AmortizationBusinessActivityAnchorCandidate> anchors;
  final bool hasMore;
}

Set<String>? _immutableStrings(Set<String>? values) =>
    values == null ? null : Set.unmodifiable(values);
