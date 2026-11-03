final class AdvanceTransactionViewQuery {
  AdvanceTransactionViewQuery({
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
  final AdvanceTransactionViewCursor? before;
  final int limit;
  final Set<String>? categoryAccountIds;
  final Set<String>? settlementAccountIds;
  final Set<String>? tagIds;
  final bool untaggedOnly;
  final String? counterpartyId;
}

final class AdvanceTransactionViewCursor {
  const AdvanceTransactionViewCursor({
    required this.anchorAt,
    required this.itemType,
    required this.ownerId,
  });

  final DateTime anchorAt;
  final String itemType;
  final String ownerId;
}

final class AdvanceTransactionViewAnchorCandidate {
  const AdvanceTransactionViewAnchorCandidate({
    required this.ownerId,
    required this.anchorTransactionId,
    required this.anchorAt,
  });

  final String ownerId;
  final String anchorTransactionId;
  final DateTime anchorAt;
}

final class AdvanceTransactionViewAnchorPage {
  AdvanceTransactionViewAnchorPage({
    required Iterable<AdvanceTransactionViewAnchorCandidate> anchors,
    required this.hasMore,
  }) : anchors = List.unmodifiable(anchors);

  final List<AdvanceTransactionViewAnchorCandidate> anchors;
  final bool hasMore;
}

Set<String>? _immutableStrings(Set<String>? values) =>
    values == null ? null : Set.unmodifiable(values);
