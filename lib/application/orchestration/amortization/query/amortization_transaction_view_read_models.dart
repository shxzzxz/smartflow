final class AmortizationTransactionViewQuery {
  AmortizationTransactionViewQuery({
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
  final AmortizationTransactionViewCursor? before;
  final int limit;
  final Set<String>? categoryAccountIds;
  final Set<String>? settlementAccountIds;
  final Set<String>? tagIds;
  final bool untaggedOnly;
  final String? counterpartyId;
}

final class AmortizationTransactionViewCursor {
  const AmortizationTransactionViewCursor({
    required this.anchorAt,
    required this.itemType,
    required this.planId,
  });

  final DateTime anchorAt;
  final String itemType;
  final String planId;
}

final class AmortizationTransactionViewAnchorCandidate {
  const AmortizationTransactionViewAnchorCandidate({
    required this.planId,
    required this.anchorTransactionId,
    required this.anchorAt,
  });

  final String planId;
  final String anchorTransactionId;
  final DateTime anchorAt;
}

final class AmortizationTransactionViewAnchorPage {
  AmortizationTransactionViewAnchorPage({
    required Iterable<AmortizationTransactionViewAnchorCandidate> anchors,
    required this.hasMore,
  }) : anchors = List.unmodifiable(anchors);

  final List<AmortizationTransactionViewAnchorCandidate> anchors;
  final bool hasMore;
}

Set<String>? _immutableStrings(Set<String>? values) =>
    values == null ? null : Set.unmodifiable(values);
